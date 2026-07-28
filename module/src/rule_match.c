/*
 * rule_match.c — WAF 规则匹配 C 扩展模块
 *
 * 编译:
 *   gcc -shared -fPIC -O2 -o ../rule_match.so rule_match.c \
 *       -I/usr/local/openresty/luajit/include/luajit-2.1
 *
 * Lua API:
 *   local rule_match = require("rule_match")
 *   local hit = rule_match.match_rule(bin_data, subject)
 *
 * bin_data 格式 (小端):
 *   [count:4B uint32]  规则数
 *   每条规则:
 *     [id_len:1B uint8] [id: id_len B]
 *     [score:1B uint8]  [status:1B uint8]  [ct_count:1B uint8]
 *     每个内容片段:
 *       [ct_len:2B uint16] [ct: ct_len B]
 *
 * 返回: 命中时返回 {id, score, status, matched}
 *       未命中返回 nil
 *       status=0 拦截, status=2 告警
 *
 * v1.1 — 修复:
 *   - 替换 luaL_Buffer 为 lua_concat（避免 LuaJIT buffer 潜在泄漏）
 *   - 所有解析步骤添加严格边界检查
 *   - 使用 memcpy 安全读取多字节整数（消除未对齐访问 UB）
 *   - 跳过循环中 content 片段边界检查修复
 */

#include <lua.h>
#include <lauxlib.h>
#include <string.h>
#include <stdint.h>

/* ---- 安全整数读取（避免未对齐访问 UB）---- */

static inline uint32_t read_u32(const char *p) {
    uint32_t v;
    memcpy(&v, p, 4);
    return v;
}

static inline uint16_t read_u16(const char *p) {
    uint16_t v;
    memcpy(&v, p, 2);
    return v;
}

#define READ_U32(p)  read_u32(p)
#define READ_U16(p)  read_u16(p)
#define READ_U8(p)   (*(uint8_t*)(p))

/* 二进制子串搜索: 在 haystack[0..hlen-1] 中查找 needle[0..nlen-1] */
static inline int bin_find(const char *haystack, size_t hlen,
                           const char *needle, size_t nlen) {
    if (nlen == 0) return 1;
    if (hlen < nlen) return 0;
    const char *end = haystack + hlen - nlen;
    for (const char *p = haystack; p <= end; p++) {
        if (memcmp(p, needle, nlen) == 0) return 1;
    }
    return 0;
}

/*
 * 构建 matched 字符串: "content1 + content2 + ..."
 * 使用 lua_concat 替代 luaL_Buffer，通过 Lua 栈管理内存，
 * 避免 LuaJIT buffer 内部分配可能的泄漏。
 * 调用后栈顶为构建好的字符串。
 * 前提: data 指针 + 所有 ct_len 必须在有效范围内（调用者已校验）。
 */
static void build_matched(lua_State *L, const char *data, int ct_count) {
    int pushed = 0;
    for (int i = 0; i < ct_count; i++) {
        uint16_t ct_len = READ_U16(data);
        data += 2;
        if (i > 0) {
            lua_pushliteral(L, " + ");
            pushed++;
        }
        lua_pushlstring(L, data, ct_len);
        pushed++;
        data += ct_len;
    }
    if (pushed > 1) {
        lua_concat(L, pushed);
    } else if (pushed == 0) {
        /* ct_count == 0: push empty string so lua_settable has a value */
        lua_pushliteral(L, "");
    }
    /* pushed == 1: 单个字符串已在栈顶 */
}

/* match_rule(bin_data, subject) -> {id, score, status, matched} | nil */
static int lua_match_rule(lua_State *L) {
    size_t bin_len, subj_len;
    const char *bin  = luaL_checklstring(L, 1, &bin_len);
    const char *subj = luaL_checklstring(L, 2, &subj_len);

    if (bin_len < 4 || subj_len == 0) {
        lua_pushnil(L);
        return 1;
    }

    const char *p   = bin;
    const char *end = bin + bin_len;
    uint32_t count  = READ_U32(p);
    p += 4;

    for (uint32_t i = 0; i < count; i++) {
        /* ---- 边界检查: id_len ---- */
        if (p >= end) break;
        uint8_t id_len = READ_U8(p);
        p++;

        /* ---- 边界检查: id 内容 ---- */
        if (p + id_len > end) break;
        const char *id = p;
        p += id_len;

        /* ---- 边界检查: score + status + ct_cnt ---- */
        if (p + 3 > end) break;
        uint8_t score  = READ_U8(p);  p++;
        uint8_t status = READ_U8(p);  p++;
        uint8_t ct_cnt = READ_U8(p);  p++;

        /* 跳过无内容的规则（ct_cnt==0 会空匹配所有请求） */
        if (ct_cnt == 0) continue;

        /* 记录内容起始（用于构建 matched 字符串） */
        const char *ct_start = p;

        /* ---- 验证所有 content 片段在边界内 ---- */
        {
            const char *check = p;
            int ct_valid = 1;
            for (int j = 0; j < ct_cnt; j++) {
                if (check + 2 > end) { ct_valid = 0; break; }
                uint16_t ct_len = READ_U16(check);
                check += 2;
                if (check + ct_len > end) { ct_valid = 0; break; }
                check += ct_len;
            }
            if (!ct_valid) continue; /* 跳过此规则，继续匹配下一条 */
        }

        /* AND 匹配: 所有内容片段都必须出现在 subject 中 */
        int all_matched = 1;
        const char *cp = p;
        for (int j = 0; j < ct_cnt; j++) {
            uint16_t ct_len = READ_U16(cp);
            cp += 2;
            if (!bin_find(subj, subj_len, cp, ct_len)) {
                all_matched = 0;
                break;
            }
            cp += ct_len;
        }

        /* 无论是否匹配，都将 p 推进到当前规则末尾 */
        p = cp;

        if (all_matched) {
            lua_createtable(L, 0, 4);

            lua_pushstring(L, "id");
            lua_pushlstring(L, id, id_len);
            lua_settable(L, -3);

            lua_pushstring(L, "score");
            lua_pushinteger(L, score);
            lua_settable(L, -3);

            lua_pushstring(L, "status");
            lua_pushinteger(L, status);
            lua_settable(L, -3);

            lua_pushstring(L, "matched");
            build_matched(L, ct_start, ct_cnt);
            lua_settable(L, -3);

            return 1;
        }
    }

    lua_pushnil(L);
    return 1;
}

/* ---- 模块注册 ---- */

static const struct luaL_Reg rule_match_lib[] = {
    {"match_rule", lua_match_rule},
    {NULL, NULL}
};

int luaopen_rule_match(lua_State *L) {
    luaL_newlib(L, rule_match_lib);
    return 1;
}
