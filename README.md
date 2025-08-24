使用lua在openresty中实现的waf功能
---

## **介绍**
1. 使用`openresty`中封装的`luajit`，配合`lua`共享内存、`redis`实现的一种基础的、可私有化部署的waf功能，提供使用`auth_basic`认证登录的控制页面。

2. 主要功能  
2.1 **`ip黑白名单`** **`限流策略`** **`区域封禁`** **`请求方法限制`** **`规则库/字段匹配`**  
2.2 使用方式
---

## **功能**
### **ip黑白名单**
使用本地文件保存ip信息，openresty每次启动时用`init_by_lua_file`加载ip文件列表的内容到预定义的共享缓存块中.

### **限流策略**
针对每一个独立的请求ip配置指定时间指定次数的访问限制，效果：
- 永久限制
- 限制指定时间
- ~~限制该ip新建连接~~

### **区域封禁**
请求进入后
- ip信息在redis中
查询属地信息保存到redis中，同时执行封禁策略

- ip信息不在redis中
从远程服务器获取属地信息

### **请求方法限制**
限制不被允许的请求方法

### **规则库/字段匹配**
在整个请求信息中匹配指定敏感字符串，如sql关键字、xss关键字

---
## 使用方式-命令行安装
1. 已经安装了`openresty`推荐版本`openresty/1.25.3.2`
2. git拉取目录到本地`/usr/local/`目录(需要调整部分文件的权限)，或直接下载release压缩包，执行内置的`install.bash`或`update.sh`脚本
2.1 `install.sh`:用于仅安装了openresty的情况，该命令会安装一个用于本地信息存储的redis，端口及密码保存在bash文件中，也可以使用本地已经安装了的数据库，可在配置文件`./module/wmxh.lua`中的`get_redis_connection`函数修改连接配置信息
2.2 `update.sh`:用于先前已经执行过了`install.sh`后续更新**或**安装了openrety、redis(已经调整了连接配置属性)的情况。

3. 使用openresty的bin目录中`opm`安装`lua-resty-http`模块，参考命令`./opm get ledgetech/lua-resty-http`

4. 解压下载的压缩包需要保存原文件权限，参考命令：`tar zxpf wmxh_25xxxx.tar.gz`
5. 进入解压后的目录，为需要执行的脚本赋予可执行权限，参考《2》
6. **安装/更新**  
安装完成后，需要在openresty的nginx.conf中引入外部配置文件
```nginx
#http块中
include /usr/local/acccontrol/conf/control_server.conf;

#需要进行访问控制的server块中
access_by_lua_file /usr/local/acccontrol/luafiles/policy-wmxh.lua;
log_by_lua_file /usr/local/acccontrol/luafiles/done_request.lua;
```

8. 至此安装完成
9. 控制页面为`http://<ip>:8042`，登录认证信息在`/usr/local/acccontrol/auth`,默认密码未提供，可安装`yum install httpd-tools -y`后使用`htpasswd -c authfile root` 重置，登录名为root.
---
## 备注
无