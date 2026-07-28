document.addEventListener("DOMContentLoaded", function () {
  if (typeof initI18n === 'function') {
    initI18n();
  }

  const sidebarGroups = document.querySelectorAll(".sidebar-group");
  const sidebarChildren = document.querySelectorAll(".sidebar-child");
  const pageTitle = document.getElementById("page-title");
  const pagePanels = document.querySelectorAll(".page-panel");

  // Language switch
  document.addEventListener('change', function(e) {
    if (e.target.matches('input[name="app-locale"]')) {
      if (typeof switchLocale === 'function') {
        switchLocale(e.target.value);
      }
    }
  });

  // Re-render on locale change
  if (typeof onLocaleChange === 'function') {
    onLocaleChange(function() {
      var current = 'dashboard';
      try { current = sessionStorage.getItem('activePage') || 'dashboard'; } catch(e) {}
      showPage(current);
    });
  }

  let provinceVisitsData = window.provinceVisitsData || {
    北京: 1200,
    上海: 980,
    广东: 860,
    台湾: 740,
    浙江: 620,
    江苏: 580,
    河南: 520,
    山东: 500,
    河北: 430,
    湖南: 400,
    湖北: 380,
    福建: 340,
    安徽: 320,
    辽宁: 300,
    黑龙江: 280,
    吉林: 260,
    四川: 240,
    重庆: 220,
    云南: 200,
    江西: 180,
    广西: 160,
    陕西: 150,
    山西: 140,
    内蒙古: 130,
    贵州: 120,
    新疆: 100,
    甘肃: 90,
    海南: 80,
    宁夏: 70,
    青海: 60,
    西藏: 50,
    天津: 35,
    澳门: 25,
    香港: 20,
  };



  function isValidIPv4(ip) {
    return /^(25[0-5]|2[0-4]\d|[01]?\d?\d)(\.(25[0-5]|2[0-4]\d|[01]?\d?\d)){3}$/.test(ip);
  }

  function fetchIpInfo(ip) {
    return fetch('/getipmsg', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ ip })
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(t('msg.ip_msg_failed'));
        }
        return response.json();
      });
  }

  function renderRegionIpInfo(info) {
    const data = info || currentRegionIpInfo || {
      ip: regionInput.value.trim() || '-',
      region_name: '-',
      country_name: '-',
      continent_code: '-'
    };

    document.getElementById('region-info-ip').textContent = data.ip || '-';
    document.getElementById('region-info-continent').textContent = data.continent_code || '-';
    document.getElementById('region-info-country').textContent = data.country_name || '-';
    document.getElementById('region-info-region').textContent = data.region_name || '-';
  }

  // Region block
  let currentRegionData = {};

  function refreshRegionTables() {
    ['province', 'country', 'continent'].forEach(function (group) {
      var prefixMap = { province: 'region_', country: 'country_', continent: 'continent_' };
      var prefix = prefixMap[group];
      var tbody = document.getElementById(group + '-table-body');
      var countEl = document.getElementById(group + '-count');
      var searchInput = document.querySelector('.region-search[data-group="' + group + '"]');
      var query = searchInput ? searchInput.value.trim().toLowerCase() : '';

      // Entries with this prefix
      var entries = [];
      for (var key in currentRegionData) {
        if (currentRegionData.hasOwnProperty(key) && key.indexOf(prefix) === 0) {
          var name = key.substring(prefix.length);
          entries.push({ key: key, name: name, value: currentRegionData[key] });
        }
      }

      entries.sort(function (a, b) {
        return a.name.localeCompare(b.name, 'zh-Hans-CN', { sensitivity: 'base', numeric: true });
      });

      // Filter by search term
      if (query) {
        entries = entries.filter(function (e) { return e.name.toLowerCase().indexOf(query) !== -1; });
      }

      var blockedCount = entries.filter(function (e) { return e.value === 0; }).length;

      // Render table
      if (!tbody) return;
      tbody.innerHTML = '';
      if (!entries.length) {
        tbody.innerHTML = '<tr><td colspan="3" class="empty-hint">' + (query ? t('region.no_results') : t('common.no_data')) + '</td></tr>';
      } else {
        entries.forEach(function (entry) {
          var isBlocked = entry.value === 0;
          var row = document.createElement('tr');
          row.innerHTML =
            '<td>' + escapeHtml(entry.name) + '</td>' +
            '<td><span class="region-status-tag ' + (isBlocked ? 'block' : 'allow') + '">' + (isBlocked ? t('region.blocked') : t('region.allowed')) + '</span></td>' +
            '<td><button type="button" class="region-toggle-btn ' + (isBlocked ? 'block' : 'allow') + '"' +
            ' data-action="toggle-region" data-key="' + escapeHtml(entry.key) + '" data-value="' + entry.value + '">' +
            (isBlocked ? t('region.unblock') : t('region.block')) + '</button></td>';
          tbody.appendChild(row);
        });
      }

      if (countEl) {
        countEl.textContent = t('region.count_format', entries.length, blockedCount);
      }
    });
  }

  function renderRegionBlockLists() {
    fetch('/getaccesscontrol')
      .then(function (response) { return response.json(); })
      .then(function (data) {
        currentRegionData = data;
        refreshRegionTables();
      })
      .catch(function (error) {
        console.error('Error fetching access control data:', error);
        currentRegionData = {};
        refreshRegionTables();
      });
  }

  function renderRateLimit() {
    fetch('/getlimitscanconf')
      .then(response => response.json())
      .then(data => {
        const enabledRadio = document.querySelector(`input[name="limit-enabled"][value="${data.maintype === 1 ? 'on' : 'off'}"]`);
        if (enabledRadio) enabledRadio.checked = true;

        // childtype: 0=permanent 1=timed 3=disconnect
        let typeValue;
        if (data.childtype === 0) typeValue = 'permanent';
        else if (data.childtype === 1) typeValue = 'timed';
        else if (data.childtype === 3) typeValue = 'disconnect';
        const typeRadio = document.querySelector(`input[name="limit-type"][value="${typeValue}"]`);
        if (typeRadio) typeRadio.checked = true;

        // Detection period
        document.getElementById('limit-permanent-period').value = data.limit_time;
        document.getElementById('limit-timed-period').value = data.limit_time;

        // Access count
        document.getElementById('limit-permanent-count').value = data.limit_number;
        document.getElementById('limit-timed-count').value = data.limit_number;

        document.getElementById('limit-timed-duration').value = data.ban_t;

        updateLimitSection();
      })
      .catch(error => {
        console.error('Error fetching rate limit config:', error);
      });
  }

  // System params: status badge

  function updateConfigBadge(key, state) {
    const badge = document.querySelector('.sys-status-badge[data-status-for="' + key + '"]');
    if (!badge) return;
    var badgeStates = {
      on:      { status: 'on',      text: t('status.badge_on') },
      off:     { status: 'off',     text: t('status.badge_off') },
      set:     { status: 'set',     text: t('status.badge_set') },
      unset:   { status: 'unset',   text: t('status.badge_unset') },
      loading: { status: 'loading', text: t('status.badge_loading') },
      unknown: { status: 'unknown', text: t('status.badge_unknown') }
    };
    var s = badgeStates[state] || badgeStates.unknown;
    badge.dataset.status = s.status;
    badge.textContent = s.text;
  }

  function refreshSystemBadgeFromDom(key) {
    if (key === 'realIpHeader') {
      var input = document.getElementById('real-ip-header');
      updateConfigBadge(key, input && input.value.trim() ? 'set' : 'unset');
    } else if (key === 'global_config') {
      var radio = document.querySelector('input[name="global-config"]:checked');
      updateConfigBadge(key, radio && radio.value === '1' ? 'on' : 'off');
    } else if (key === 'policystatus') {
      var radio = document.querySelector('input[name="policy-status"]:checked');
      updateConfigBadge(key, radio && radio.value === '1' ? 'on' : 'off');
    } else if (key === 'full_log') {
      var radio = document.querySelector('input[name="full-log"]:checked');
      updateConfigBadge(key, radio && radio.value === '1' ? 'on' : 'off');
    } else if (key === 'active_time') {
      var sel = document.getElementById('active-time-select');
      updateConfigBadge(key, sel && sel.value !== undefined ? 'set' : 'unset');
    }
  }

  function saveSystemConfig(key, body, okMsgKey) {
    var badge = document.querySelector('.sys-status-badge[data-status-for="' + key + '"]');
    var card = document.querySelector('[data-config-card="' + key + '"]');
    var btn  = card ? card.querySelector('[data-save-btn]') : null;
    if (badge) updateConfigBadge(key, 'loading');
    if (btn) { btn.disabled = true; btn.textContent = '…'; }

    fetch('/updateglobalconfig', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    })
      .then(function (r) {
        if (btn) { btn.disabled = false; btn.textContent = t('common.save'); }
        if (r.ok) {
          alert(t(okMsgKey));
          refreshSystemBadgeFromDom(key);
        } else {
          alert(t('msg.save_failed'));
          refreshSystemBadgeFromDom(key);
        }
      })
      .catch(function (err) {
        console.error('Error:', err);
        if (btn) { btn.disabled = false; btn.textContent = t('common.save'); }
        alert(t('msg.save_failed'));
        refreshSystemBadgeFromDom(key);
      });
  }

  // Render system params

  function renderSystemParams() {
    var badges = document.querySelectorAll('.sys-status-badge[data-status-for]');
    for (var i = 0; i < badges.length; i++) {
      badges[i].dataset.status = 'loading';
      badges[i].textContent = t('status.badge_loading');
    }

    fetch('/getglobalconfig')
      .then(function (response) {
        if (!response.ok) throw new Error('HTTP ' + response.status);
        return response.json();
      })
      .then(function (data) {
        // Global rules
        var globalRadio = document.querySelector('input[name="global-config"][value="' + data.global_config + '"]');
        if (globalRadio) globalRadio.checked = true;
        updateConfigBadge('global_config', data.global_config == 1 ? 'on' : 'off');

        // Signature matching
        var policyRadio = document.querySelector('input[name="policy-status"][value="' + data.policystatus + '"]');
        if (policyRadio) policyRadio.checked = true;
        updateConfigBadge('policystatus', data.policystatus == 1 ? 'on' : 'off');

        // Full logging
        var fullLogRadio = document.querySelector('input[name="full-log"][value="' + data.full_log + '"]');
        if (fullLogRadio) fullLogRadio.checked = true;
        updateConfigBadge('full_log', data.full_log == 1 ? 'on' : 'off');

        // Real IP config
        var ipEl = document.getElementById('real-ip-header');
        if (ipEl) ipEl.value = data.realIpHeader || '';
        updateConfigBadge('realIpHeader', data.realIpHeader && data.realIpHeader.trim() ? 'set' : 'unset');

        // Login expiry
        var activeTimeEl = document.getElementById('active-time-select');
        if (activeTimeEl) {
          var activeTime = data.active_time !== undefined ? String(data.active_time) : '0';
          activeTimeEl.value = activeTime;
          updateConfigBadge('active_time', 'set');
        }
      })
      .catch(function (error) {
        console.error('Error fetching system config:', error);
        var badges = document.querySelectorAll('.sys-status-badge[data-status-for]');
        for (var i = 0; i < badges.length; i++) {
          badges[i].dataset.status = 'unknown';
          badges[i].textContent = t('status.badge_load_failed');
        }
      });
  }

  // HTTP log data (from server)
  let currentHttpLogs = [];
  let httpLogTotal = 0;

  // HTTP log pagination state
  let logPageSize = 10;
  let logCurrentPage = 1;

  function getLogTotalPages() {
    return Math.max(1, Math.ceil(currentHttpLogs.length / logPageSize));
  }

  // Path rules local state
  let currentPathRules = [];

  // Header rules local state
  let currentHeaderRules = [];

  // Method rules local state
  let currentMethods = [];

  // Anti-scan status codes local state
  let currentScanCodes = [];

  // China map state
  let chinaMap = null;
  let chinaMapGeoLayer = null;
  let chinaMapInited = false;
  let _provinceRegion = {};
  let _regionColors = {};

  // World map state
  let worldMapData = null;   // GeoJSON features
  let worldMapGeoLayer = null;
  let worldMapInited = false;
  let countryVisitsData = {};
  let currentMapType = 'china';
  let _worldCurrentLayer = null;

  // Black/white list local state
  let currentBlacklist = [];
  let currentWhitelist = [];

  function formatTime(ts) {
    if (!ts || ts === 0) return '—';
    var d = new Date(ts * 1000);
    var pad = function (n) { return n < 10 ? '0' + n : '' + n; };
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
      ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
  }

  function refreshIpTable(type, items) {
    var tbody = document.getElementById(type + '-table-body');
    var countEl = document.getElementById(type + '-count');
    if (!tbody) return;
    tbody.innerHTML = '';
    if (!items.length) {
      tbody.innerHTML = '<tr><td colspan="3" class="empty-hint">' + t('bw.no_' + type) + '</td></tr>';
    } else {
      items.forEach(function (entry, index) {
        var ip = typeof entry === 'string' ? entry : entry.ip;
        var time = (typeof entry === 'object' && entry.time) ? entry.time : 0;
        var row = document.createElement('tr');
        row.innerHTML =
          '<td><input type="checkbox" class="' + type + '-row-check" data-index="' + index + '" data-ip="' + escapeHtml(ip) + '"></td>' +
          '<td>' + escapeHtml(ip) + '</td>' +
          '<td>' + formatTime(time) + '</td>';
        tbody.appendChild(row);
      });
    }
    if (countEl) countEl.textContent = t('bw.count_format', items.length);
  }

  function refreshBlackWhiteTables() {
    refreshIpTable('blacklist', currentBlacklist);
    refreshIpTable('whitelist', currentWhitelist);
  }

  function renderBlackWhiteLists() {
    fetch('/getiplist')
      .then(function (response) { return response.json(); })
      .then(function (data) {
        currentBlacklist = data.blacklist_ipaddr || [];
        currentWhitelist = data.whitelist_ipaddr || [];
        refreshBlackWhiteTables();
      })
      .catch(function (error) {
        console.error('Error fetching IP lists:', error);
        currentBlacklist = [];
        currentWhitelist = [];
        refreshBlackWhiteTables();
      });
  }

  function renderPathRules() {
    fetch('/getpathrules')
      .then(response => response.json())
      .then(data => {
        currentPathRules = Array.isArray(data) ? data : [];
        refreshPathRuleTable();
      })
      .catch(error => {
        console.error('Error fetching path rules:', error);
        currentPathRules = [];
        refreshPathRuleTable();
      });
  }

  function refreshPathRuleTable() {
    const body = document.getElementById("path-rule-table-body");
    const countEl = document.getElementById("path-rule-count");
    if (!body) return;

    body.innerHTML = "";
    if (!currentPathRules.length) {
      body.innerHTML = '<tr><td colspan="5" class="empty-hint">' + t('path.no_rules') + '</td></tr>';
    } else {
      const typeLabels = { whitelist: t("path.whitelist"), blacklist: t("path.blacklist") };
      const matchLabels = { prefix: t("path.match_prefix"), exact: t("path.match_exact") };
      const actionLabels = { allow: t("path.action_allow"), block: t("path.action_block") };

      currentPathRules.forEach((rule, index) => {
        const row = document.createElement("tr");
        row.innerHTML = `
          <td>${escapeHtml(rule.path)}</td>
          <td>${typeLabels[rule.rule_type] || rule.rule_type}</td>
          <td>${matchLabels[rule.match_type] || rule.match_type}</td>
          <td>${actionLabels[rule.action] || rule.action}</td>
          <td>
            <button type="button" class="btn btn-outline btn-sm" data-action="delete-path-rule" data-index="${index}">t('common.delete')</button>
          </td>
        `;
        body.appendChild(row);
      });
    }

    if (countEl) {
      countEl.textContent = t('path.count', currentPathRules.length);
    }
  }

  function addPathRule() {
    const pathInput = document.getElementById("path-rule-input");
    const typeSelect = document.getElementById("path-rule-type");
    const matchSelect = document.getElementById("path-rule-match");
    const actionSelect = document.getElementById("path-rule-action");

    const path = pathInput.value.trim();
    if (!path) {
      alert(t("msg.input_path"));
      return;
    }

    const rule = {
      path: path,
      rule_type: typeSelect.value,
      match_type: matchSelect.value,
      action: actionSelect.value
    };

    currentPathRules.push(rule);
    refreshPathRuleTable();
    pathInput.value = "";
    pathInput.focus();
  }

  function deletePathRule(index) {
    if (index >= 0 && index < currentPathRules.length) {
      currentPathRules.splice(index, 1);
      refreshPathRuleTable();
    }
  }

  function savePathRules() {
    fetch('/updatepathrules', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(currentPathRules)
    })
      .then(response => {
        if (response.ok) {
          alert(t('msg.path_saved', currentPathRules.length));
        } else {
          alert(t('msg.save_failed'));
        }
      })
      .catch(error => {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  }

  function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  let pathRuleEventsInited = false;

  function initPathRuleEvents() {
    if (pathRuleEventsInited) return;
    pathRuleEventsInited = true;

    const addBtn = document.getElementById("path-rule-add-btn");
    if (addBtn) {
      addBtn.addEventListener("click", addPathRule);
    }

    const saveBtn = document.getElementById("path-rule-save-btn");
    if (saveBtn) {
      saveBtn.addEventListener("click", savePathRules);
    }

    const pathInput = document.getElementById("path-rule-input");
    if (pathInput) {
      pathInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          addPathRule();
        }
      });
    }

    // Delete button event delegation
    const tableBody = document.getElementById("path-rule-table-body");
    if (tableBody) {
      tableBody.addEventListener("click", function (event) {
        const target = event.target.closest("button[data-action='delete-path-rule']");
        if (!target) return;
        const index = parseInt(target.dataset.index, 10);
        if (!isNaN(index)) {
          deletePathRule(index);
        }
      });
    }
  }

  // Header rules

  function renderHeaderRules() {
    fetch('/getheaderrules')
      .then(response => response.json())
      .then(data => {
        currentHeaderRules = Array.isArray(data) ? data : [];
        refreshHeaderRuleTable();
      })
      .catch(error => {
        console.error('Error fetching header rules:', error);
        currentHeaderRules = [];
        refreshHeaderRuleTable();
      });
  }

  function refreshHeaderRuleTable() {
    const body = document.getElementById("header-rule-table-body");
    const countEl = document.getElementById("header-rule-count");
    if (!body) return;

    body.innerHTML = "";
    if (!currentHeaderRules.length) {
      body.innerHTML = '<tr><td colspan="6" class="empty-hint">' + t('header.no_rules') + '</td></tr>';
    } else {
      const typeLabels = { whitelist: t("path.whitelist"), blacklist: t("path.blacklist") };
      const matchLabels = { exact: t("header.match_exact"), prefix: t("header.match_prefix"), contains: t("header.match_contains") };
      const actionLabels = { allow: t("path.action_allow"), block: t("path.action_block") };

      currentHeaderRules.forEach((rule, index) => {
        const row = document.createElement("tr");
        row.innerHTML = `
          <td>${escapeHtml(rule.header_name)}</td>
          <td>${typeLabels[rule.rule_type] || rule.rule_type}</td>
          <td>${matchLabels[rule.match_type] || rule.match_type}</td>
          <td>${escapeHtml(rule.value)}</td>
          <td>${actionLabels[rule.action] || rule.action}</td>
          <td>
            <button type="button" class="btn btn-outline btn-sm" data-action="delete-header-rule" data-index="${index}">t('common.delete')</button>
          </td>
        `;
        body.appendChild(row);
      });
    }

    if (countEl) {
      countEl.textContent = t('header.count', currentHeaderRules.length);
    }
  }

  function addHeaderRule() {
    const nameInput = document.getElementById("header-rule-input");
    const typeSelect = document.getElementById("header-rule-type");
    const matchSelect = document.getElementById("header-rule-match");
    const valueInput = document.getElementById("header-rule-value");
    const actionSelect = document.getElementById("header-rule-action");

    const headerName = nameInput.value.trim();
    const value = valueInput.value.trim();

    if (!headerName) {
      alert(t("msg.input_header_name"));
      return;
    }
    if (!value) {
      alert(t("msg.input_header_value"));
      return;
    }

    const rule = {
      header_name: headerName,
      rule_type: typeSelect.value,
      match_type: matchSelect.value,
      value: value,
      action: actionSelect.value
    };

    currentHeaderRules.push(rule);
    refreshHeaderRuleTable();
    nameInput.value = "";
    valueInput.value = "";
    nameInput.focus();
  }

  function deleteHeaderRule(index) {
    if (index >= 0 && index < currentHeaderRules.length) {
      currentHeaderRules.splice(index, 1);
      refreshHeaderRuleTable();
    }
  }

  function saveHeaderRules() {
    fetch('/updateheaderrules', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(currentHeaderRules)
    })
      .then(response => {
        if (response.ok) {
          alert(t('msg.header_saved', currentHeaderRules.length));
        } else {
          alert(t('msg.save_failed'));
        }
      })
      .catch(error => {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  }

  let headerRuleEventsInited = false;

  function initHeaderRuleEvents() {
    if (headerRuleEventsInited) return;
    headerRuleEventsInited = true;

    const addBtn = document.getElementById("header-rule-add-btn");
    if (addBtn) {
      addBtn.addEventListener("click", addHeaderRule);
    }

    const saveBtn = document.getElementById("header-rule-save-btn");
    if (saveBtn) {
      saveBtn.addEventListener("click", saveHeaderRules);
    }

    const nameInput = document.getElementById("header-rule-input");
    if (nameInput) {
      nameInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          addHeaderRule();
        }
      });
    }

    const valueInput = document.getElementById("header-rule-value");
    if (valueInput) {
      valueInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          addHeaderRule();
        }
      });
    }

    // Delete button event delegation
    const tableBody = document.getElementById("header-rule-table-body");
    if (tableBody) {
      tableBody.addEventListener("click", function (event) {
        const target = event.target.closest("button[data-action='delete-header-rule']");
        if (!target) return;
        const index = parseInt(target.dataset.index, 10);
        if (!isNaN(index)) {
          deleteHeaderRule(index);
        }
      });
    }
  }

  // Signature rules: server-side filter+page, inline edit, add modal
  const SIG_SCOPE_LABELS = { uri: t("sig.scope_uri"), param: t("sig.scope_param"), header: t("sig.scope_header") };
  const SIG_STATUS_META = {
    0: { label: t("sig.status_on"), cls: "on" },
    1: { label: t("sig.status_off"), cls: "off" },
    2: { label: t("sig.status_alert"), cls: "alert" },
  };
  let currentSigRules = []; // Current page rules (server page, only current)
  let sigTotal = 0;
  let sigCurrentPage = 1;
  let sigPageSize = 15;
  let sigEditing = false; // Whether row is being edited
  let sigAddContents = []; // Rule contents added in modal
  let sigRuleEventsInited = false;
  let sigSelectedIds = {}; // Cross-page selected rule IDs {id: {category, id}}

  function getSigTotalPages() {
    return Math.max(1, Math.ceil(sigTotal / sigPageSize));
  }

  function fetchSignatureRules() {
    const params = new URLSearchParams();
    const idEl = document.getElementById("sig-filter-id");
    const contentEl = document.getElementById("sig-filter-content");
    const categoryEl = document.getElementById("sig-filter-category");
    const scoreEl = document.getElementById("sig-filter-score");
    const statusEl = document.getElementById("sig-filter-status");
    if (idEl && idEl.value.trim()) params.set("rule_id", idEl.value.trim());
    if (contentEl && contentEl.value.trim()) params.set("content", contentEl.value.trim());
    if (categoryEl && categoryEl.value !== "") params.set("category", categoryEl.value);
    if (scoreEl && scoreEl.value !== "") params.set("score", scoreEl.value);
    if (statusEl && statusEl.value !== "") params.set("status", statusEl.value);
    params.set("page", sigCurrentPage);
    params.set("page_size", sigPageSize);
    fetch("/getsignaturerules?" + params.toString())
      .then((response) => response.json())
      .then((data) => {
        sigTotal = data.total || 0;
        currentSigRules = Array.isArray(data.rules) ? data.rules : [];
        // Fallback to last page if current exceeds total
        if (!currentSigRules.length && sigTotal > 0 && sigCurrentPage > 1) {
          sigCurrentPage = getSigTotalPages();
          fetchSignatureRules();
          return;
        }
        sigEditing = false;
        renderSigTable();
      })
      .catch((error) => {
        console.error("Error fetching signature rules:", error);
        sigTotal = 0;
        currentSigRules = [];
        renderSigTable();
      });
  }

  function renderSigTable() {
    const body = document.getElementById("sig-table-body");
    if (!body) return;
    body.innerHTML = "";
    if (!currentSigRules.length) {
      body.innerHTML = '<tr><td colspan="9">' + t("sig.no_rules") + '</td></tr>';
      renderSigPagination();
      updateSigDeleteButton();
      return;
    }
    currentSigRules.forEach((rule, index) => {
      const contents = Array.isArray(rule.contents) ? rule.contents : [];
      const statusMeta = SIG_STATUS_META[rule.status] || { label: String(rule.status), cls: "off" };
      let contentCell;
      if (contents.length > 1) {
        contentCell = '<button type="button" class="btn btn-outline btn-sm" data-action="sig-view-content" data-index="' + index + '">' + t('common.view') + '</button>';
      } else {
        contentCell = escapeHtml(contents[0] || "");
      }
      const selKey = rule.category + ":" + rule.id;
      const checked = sigSelectedIds[selKey] ? " checked" : "";
      const row = document.createElement("tr");
      row.innerHTML = `
        <td class="col-sigcheck"><input type="checkbox" class="sig-row-check" data-key="${escapeHtml(selKey)}" data-cat="${escapeHtml(rule.category)}" data-id="${escapeHtml(String(rule.id))}"${checked}></td>
        <td class="col-sigid">${escapeHtml(String(rule.id))}</td>
        <td class="col-sigscore">${escapeHtml(String(rule.score))}</td>
        <td class="col-sigscope">${SIG_SCOPE_LABELS[rule.category] || escapeHtml(String(rule.category))}</td>
        <td class="col-signame" title="${escapeHtml(rule.name || "")}">${escapeHtml(rule.name || "")}</td>
        <td class="col-sigdesc" title="${escapeHtml(rule.desc || "")}">${escapeHtml(rule.desc || "")}</td>
        <td class="col-sigcontent" title="${contents.length === 1 ? escapeHtml(contents[0] || "") : ""}">${contentCell}</td>
        <td class="col-sigstatus"><span class="sig-status-tag ${statusMeta.cls}">${statusMeta.label}</span></td>
        <td class="col-sigaction"><button type="button" class="btn btn-outline btn-sm" data-action="sig-edit" data-index="${index}">${t('common.edit')}</button></td>
      `;
      body.appendChild(row);
    });
    renderSigPagination();
    updateSigDeleteButton();
    updateSigSelectAllCheckbox();
  }

  function renderSigPagination() {
    const totalPages = getSigTotalPages();
    const info = document.getElementById("sig-page-info");
    if (info) info.textContent = t("sig.page_info", sigCurrentPage, totalPages, sigTotal);
    const firstBtn = document.getElementById("sig-page-first");
    const prevBtn = document.getElementById("sig-page-prev");
    const nextBtn = document.getElementById("sig-page-next");
    const lastBtn = document.getElementById("sig-page-last");
    if (firstBtn) firstBtn.disabled = sigCurrentPage <= 1;
    if (prevBtn) prevBtn.disabled = sigCurrentPage <= 1;
    if (nextBtn) nextBtn.disabled = sigCurrentPage >= totalPages;
    if (lastBtn) lastBtn.disabled = sigCurrentPage >= totalPages;
    const jumpEl = document.getElementById("sig-page-jump");
    if (jumpEl) jumpEl.max = totalPages;
  }

  function goToSigPage(page) {
    page = parseInt(page, 10);
    if (isNaN(page)) return;
    const totalPages = getSigTotalPages();
    if (page < 1) page = 1;
    if (page > totalPages) page = totalPages;
    sigCurrentPage = page;
    fetchSignatureRules();
  }

  function changeSigPageSize(size) {
    size = parseInt(size, 10);
    if (isNaN(size) || size < 1) return;
    sigPageSize = size;
    sigCurrentPage = 1;
    fetchSignatureRules();
  }

  // Inline edit
  function enterSigEdit(index) {
    if (sigEditing) {
      renderSigTable();
    }
    const rule = currentSigRules[index];
    const body = document.getElementById("sig-table-body");
    if (!rule || !body || !body.children[index]) return;
    sigEditing = true;
    const row = body.children[index];
    // Score dropdown
    let scoreOpts = "";
    for (let s = 1; s <= 10; s++) {
      scoreOpts += '<option value="' + s + '"' + (Number(rule.score) === s ? " selected" : "") + ">" + s + "</option>";
    }
    row.cells[1].innerHTML = '<select class="sig-edit-select" data-field="score">' + scoreOpts + "</select>";
    // Status dropdown
    let statusOpts = "";
    [[0, "0-" + t("sig.status_on")], [1, "1-" + t("sig.status_off")], [2, "2-" + t("sig.status_alert")]].forEach(function (pair) {
      statusOpts += '<option value="' + pair[0] + '"' + (Number(rule.status) === pair[0] ? " selected" : "") + ">" + pair[1] + "</option>";
    });
    row.cells[6].innerHTML = '<select class="sig-edit-select" data-field="status">' + statusOpts + "</select>";
    // Action cell: save/cancel
    row.cells[7].innerHTML =
      '<button type="button" class="btn btn-primary btn-sm" data-action="sig-save" data-index="' + index + '">' + t('common.save') + '</button>' +
      '<button type="button" class="btn btn-outline btn-sm" data-action="sig-cancel" data-index="' + index + '">' + t('common.cancel') + '</button>';
  }

  function saveSigEdit(index) {
    const rule = currentSigRules[index];
    const body = document.getElementById("sig-table-body");
    if (!rule || !body || !body.children[index]) return;
    const row = body.children[index];
    const scoreSel = row.querySelector('select[data-field="score"]');
    const statusSel = row.querySelector('select[data-field="status"]');
    const payload = {
      category: rule.category,
      id: rule.id,
      score: parseInt(scoreSel ? scoreSel.value : rule.score, 10),
      status: parseInt(statusSel ? statusSel.value : rule.status, 10),
    };
    fetch("/updatesignaturerule", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    })
      .then((response) => response.json().then((data) => ({ ok: response.ok, data: data })))
      .then((result) => {
        if (result.ok && result.data && result.data.msg === "update_ok") {
          fetchSignatureRules();
        } else {
          alert(t("msg.save_rule_failed", ((result.data && result.data.msg) || "Unknown error")));
        }
      })
      .catch((error) => {
        console.error("Error updating signature rule:", error);
        alert(t("msg.save_failed"));
      });
  }

  // Rule content view modal
  function openSigContentModal(rule) {
    const modal = document.getElementById("sig-content-modal");
    const body = document.getElementById("sig-content-body");
    if (!modal || !body) return;
    const contents = Array.isArray(rule.contents) ? rule.contents : [];
    let text = t("sig.content_body", rule.id, contents.length) + "\n\n";
    contents.forEach(function (c, i) {
      text += "  " + (i + 1) + ". " + c + "\n";
    });
    body.textContent = text; // Plain text, prevent XSS
    modal.classList.remove("hidden");
  }

  function closeSigContentModal() {
    const modal = document.getElementById("sig-content-modal");
    if (modal) modal.classList.add("hidden");
  }

  // Add rule modal
  function openSigAddModal() {
    const modal = document.getElementById("sig-add-modal");
    if (!modal) return;
    sigAddContents = [];
    const nameEl = document.getElementById("sig-add-name");
    if (nameEl) nameEl.value = "";
    const descEl = document.getElementById("sig-add-desc");
    if (descEl) descEl.value = "";
    const contentInput = document.getElementById("sig-add-content-input");
    if (contentInput) contentInput.value = "";
    const catEl = document.getElementById("sig-add-category");
    if (catEl) catEl.value = "uri";
    const scoreEl = document.getElementById("sig-add-score");
    if (scoreEl) scoreEl.value = "5";
    const statusEl = document.getElementById("sig-add-status");
    if (statusEl) statusEl.value = "0";
    renderSigAddContentTags();
    modal.classList.remove("hidden");
  }

  function closeSigAddModal() {
    const modal = document.getElementById("sig-add-modal");
    if (modal) modal.classList.add("hidden");
  }

  function renderSigAddContentTags() {
    const wrap = document.getElementById("sig-add-content-tags");
    if (!wrap) return;
    if (!sigAddContents.length) {
      wrap.innerHTML = '<span class="sig-add-empty">' + t('sig.add_content_empty') + '</span>';
      return;
    }
    wrap.innerHTML = sigAddContents
      .map(function (c, i) {
        return '<span class="method-tag">' + escapeHtml(c) +
          '<button type="button" class="method-tag-remove" data-action="sig-content-remove" data-index="' + i + '" title="' + t('common.delete') + '">&times;</button></span>';
      })
      .join("");
  }

  function addSigAddContent() {
    const input = document.getElementById("sig-add-content-input");
    if (!input) return;
    const val = input.value.trim();
    if (!val) return;
    if (sigAddContents.indexOf(val) !== -1) {
      alert(t("msg.already_added"));
      return;
    }
    sigAddContents.push(val);
    input.value = "";
    input.focus();
    renderSigAddContentTags();
  }

  function submitSigAdd() {
    const nameEl = document.getElementById("sig-add-name");
    const descEl = document.getElementById("sig-add-desc");
    const catEl = document.getElementById("sig-add-category");
    const scoreEl = document.getElementById("sig-add-score");
    const statusEl = document.getElementById("sig-add-status");
    const name = nameEl ? nameEl.value.trim() : "";
    if (!name) {
      alert(t("msg.add_rule_name"));
      return;
    }
    if (!sigAddContents.length) {
      alert(t("msg.add_rule_content"));
      return;
    }
    const payload = {
      category: catEl ? catEl.value : "uri",
      name: name,
      desc: descEl ? descEl.value.trim() : "",
      contents: sigAddContents,
      score: parseInt(scoreEl ? scoreEl.value : "5", 10),
      status: parseInt(statusEl ? statusEl.value : "0", 10),
    };
    fetch("/addsignaturerule", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    })
      .then((response) => response.json().then((data) => ({ ok: response.ok, data: data })))
      .then((result) => {
        if (result.ok && result.data && result.data.msg === "add_ok") {
          alert(t("msg.add_rule_success", result.data.id));
          closeSigAddModal();
          fetchSignatureRules();
        } else {
          alert(t("msg.add_rule_failed", ((result.data && result.data.msg) || "Unknown error")));
        }
      })
      .catch((error) => {
        console.error("Error adding signature rule:", error);
        alert(t("msg.add_failed_retry"));
      });
  }

  // Event binding (dedup)
  // Multi-select delete helper

  function updateSigDeleteButton() {
    const btn = document.getElementById("sig-delete-btn");
    if (!btn) return;
    const count = Object.keys(sigSelectedIds).length;
    btn.disabled = count === 0;
    btn.textContent = count > 0 ? t("sig.delete_selected_n", count) : t("sig.delete_selected");
  }

  function updateSigSelectAllCheckbox() {
    const selectAll = document.getElementById("sig-select-all");
    if (!selectAll) return;
    const checkboxes = document.querySelectorAll("#sig-table-body .sig-row-check");
    if (checkboxes.length === 0) {
      selectAll.checked = false;
      return;
    }
    selectAll.checked = true;
    checkboxes.forEach(function(cb) {
      if (!cb.checked) selectAll.checked = false;
    });
  }

  function doDeleteSelectedRules() {
    const entries = Object.values(sigSelectedIds);
    if (entries.length === 0) return;
    if (!confirm(t("confirm.delete_rules", entries.length))) return;

    // Group by category
    var groups = {};
    entries.forEach(function(e) {
      if (!groups[e.category]) groups[e.category] = [];
      groups[e.category].push(e.id);
    });

    var cats = Object.keys(groups);
    var completed = 0;

    function doNext() {
      if (completed >= cats.length) {
      // All done, clear selection and refresh
        sigSelectedIds = {};
        sigCurrentPage = 1;
        fetchSignatureRules();
        return;
      }
      var cat = cats[completed];
      fetch("/deletesignaturerules", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ category: cat, ids: groups[cat] }),
      })
        .then(function(r) { return r.json(); })
        .then(function(data) {
          if (data.msg === "delete_ok") {
            console.log("Deleted " + data.deleted + " rules from " + cat);
          }
          completed++;
          doNext();
        })
        .catch(function(err) {
          console.error("Error deleting rules from " + cat + ":", err);
          completed++;
          doNext();
        });
    }
    doNext();
  }

  function initSignatureRuleEvents() {
    if (sigRuleEventsInited) return;
    sigRuleEventsInited = true;

    // Select all checkbox
    const selectAll = document.getElementById("sig-select-all");
    if (selectAll) {
      selectAll.addEventListener("change", function() {
        var checked = this.checked;
        document.querySelectorAll("#sig-table-body .sig-row-check").forEach(function(cb) {
          cb.checked = checked;
          var key = cb.dataset.key;
          var cat = cb.dataset.cat;
          var id = cb.dataset.id;
          if (checked) {
            sigSelectedIds[key] = { category: cat, id: id };
          } else {
            delete sigSelectedIds[key];
          }
        });
        updateSigDeleteButton();
      });
    }

    // Batch delete button
    const delBtn = document.getElementById("sig-delete-btn");
    if (delBtn) {
      delBtn.addEventListener("click", doDeleteSelectedRules);
    }

    // Search / Reset
    const searchBtn = document.getElementById("sig-filter-search");
    if (searchBtn) {
      searchBtn.addEventListener("click", function () {
        sigCurrentPage = 1;
        fetchSignatureRules();
      });
    }
    const clearBtn = document.getElementById("sig-filter-clear");
    if (clearBtn) {
      clearBtn.addEventListener("click", function () {
        const idEl = document.getElementById("sig-filter-id");
        if (idEl) idEl.value = "";
        const contentEl = document.getElementById("sig-filter-content");
        if (contentEl) contentEl.value = "";
        const categoryEl = document.getElementById("sig-filter-category");
        if (categoryEl) categoryEl.value = "";
        const scoreEl = document.getElementById("sig-filter-score");
        if (scoreEl) scoreEl.value = "";
        const statusEl = document.getElementById("sig-filter-status");
        if (statusEl) statusEl.value = "";
        sigCurrentPage = 1;
        fetchSignatureRules();
      });
    }
    const idInput = document.getElementById("sig-filter-id");
    if (idInput) {
      idInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          sigCurrentPage = 1;
          fetchSignatureRules();
        }
      });
    }
    const contentFilterInput = document.getElementById("sig-filter-content");
    if (contentFilterInput) {
      contentFilterInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          sigCurrentPage = 1;
          fetchSignatureRules();
        }
      });
    }

    // Pagination controls
    const pageSizeEl = document.getElementById("sig-page-size");
    if (pageSizeEl) {
      pageSizeEl.addEventListener("change", function () {
        changeSigPageSize(this.value);
      });
    }
    const firstBtn = document.getElementById("sig-page-first");
    if (firstBtn) firstBtn.addEventListener("click", function () { goToSigPage(1); });
    const prevBtn = document.getElementById("sig-page-prev");
    if (prevBtn) prevBtn.addEventListener("click", function () { goToSigPage(sigCurrentPage - 1); });
    const nextBtn = document.getElementById("sig-page-next");
    if (nextBtn) nextBtn.addEventListener("click", function () { goToSigPage(sigCurrentPage + 1); });
    const lastBtn = document.getElementById("sig-page-last");
    if (lastBtn) lastBtn.addEventListener("click", function () { goToSigPage(getSigTotalPages()); });
    const goBtn = document.getElementById("sig-page-go");
    const jumpEl = document.getElementById("sig-page-jump");
    if (goBtn && jumpEl) {
      goBtn.addEventListener("click", function () { goToSigPage(jumpEl.value); });
      jumpEl.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          goToSigPage(this.value);
        }
      });
    }

    // Table event delegation: checkbox/view/edit/save/cancel
    const tableBody = document.getElementById("sig-table-body");
    if (tableBody) {
      tableBody.addEventListener("click", function (event) {
        // Handle row checkbox
        const cb = event.target.closest("input.sig-row-check");
        if (cb) {
          var key = cb.dataset.key;
          var cat = cb.dataset.cat;
          var id = cb.dataset.id;
          if (cb.checked) {
            sigSelectedIds[key] = { category: cat, id: id };
          } else {
            delete sigSelectedIds[key];
          }
          updateSigDeleteButton();
          updateSigSelectAllCheckbox();
          return;
        }

        // Handle button actions
        const target = event.target.closest("button[data-action]");
        if (!target) return;
        const action = target.dataset.action;
        const index = parseInt(target.dataset.index, 10);
        if (isNaN(index)) return;
        if (action === "sig-view-content") {
          if (currentSigRules[index]) openSigContentModal(currentSigRules[index]);
        } else if (action === "sig-edit") {
          enterSigEdit(index);
        } else if (action === "sig-save") {
          saveSigEdit(index);
        } else if (action === "sig-cancel") {
          sigEditing = false;
          renderSigTable();
        }
      });
    }

    // Content view modal close
    const contentClose = document.getElementById("sig-content-close");
    if (contentClose) contentClose.addEventListener("click", closeSigContentModal);
    const contentModal = document.getElementById("sig-content-modal");
    if (contentModal) {
      const backdrop = contentModal.querySelector(".modal-backdrop");
      if (backdrop) backdrop.addEventListener("click", closeSigContentModal);
    }

    // Add modal
    const addBtn = document.getElementById("sig-add-btn");
    if (addBtn) addBtn.addEventListener("click", openSigAddModal);
    const addCancel = document.getElementById("sig-add-cancel");
    if (addCancel) addCancel.addEventListener("click", closeSigAddModal);
    const addConfirm = document.getElementById("sig-add-confirm");
    if (addConfirm) addConfirm.addEventListener("click", submitSigAdd);
    const addModal = document.getElementById("sig-add-modal");
    if (addModal) {
      const backdrop = addModal.querySelector(".modal-backdrop");
      if (backdrop) backdrop.addEventListener("click", closeSigAddModal);
    }
    const contentAddBtn = document.getElementById("sig-add-content-add");
    if (contentAddBtn) contentAddBtn.addEventListener("click", addSigAddContent);
    const contentInput = document.getElementById("sig-add-content-input");
    if (contentInput) {
      contentInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          addSigAddContent();
        }
      });
    }
    const contentTags = document.getElementById("sig-add-content-tags");
    if (contentTags) {
      contentTags.addEventListener("click", function (event) {
        const target = event.target.closest("button[data-action='sig-content-remove']");
        if (!target) return;
        const index = parseInt(target.dataset.index, 10);
        if (!isNaN(index)) {
          sigAddContents.splice(index, 1);
          renderSigAddContentTags();
        }
      });
    }

    // ESC close modal
    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape") return;
      const cm = document.getElementById("sig-content-modal");
      if (cm && !cm.classList.contains("hidden")) closeSigContentModal();
      const am = document.getElementById("sig-add-modal");
      if (am && !am.classList.contains("hidden")) closeSigAddModal();
    });
  }

  // Param rules

  let currentParamRules = [];

  function renderParamRules() {
    fetch('/getparamrules')
      .then(response => response.json())
      .then(data => {
        currentParamRules = Array.isArray(data) ? data : [];
        refreshParamRuleTable();
      })
      .catch(error => {
        console.error('Error fetching param rules:', error);
        currentParamRules = [];
        refreshParamRuleTable();
      });
  }

  function refreshParamRuleTable() {
    const body = document.getElementById("param-rule-table-body");
    const countEl = document.getElementById("param-rule-count");
    if (!body) return;

    body.innerHTML = "";
    if (!currentParamRules.length) {
      body.innerHTML = '<tr><td colspan="5" class="empty-hint">' + t('path.no_rules') + '</td></tr>';
    } else {
      const matchLabels = { exact: t("header.match_exact"), prefix: t("header.match_prefix"), contains: t("header.match_contains") };
      const actionLabels = { block: t("param.action_block"), intercept: t("param.action_intercept") };

      currentParamRules.forEach((rule, index) => {
        const row = document.createElement("tr");
        row.innerHTML = `
          <td>${escapeHtml(rule.param_name)}</td>
          <td>${matchLabels[rule.match_type] || rule.match_type}</td>
          <td>${escapeHtml(rule.value)}</td>
          <td>${actionLabels[rule.action] || rule.action}</td>
          <td>
            <button type="button" class="btn btn-outline btn-sm" data-action="delete-param-rule" data-index="${index}">t('common.delete')</button>
          </td>
        `;
        body.appendChild(row);
      });
    }

    if (countEl) {
      countEl.textContent = t('param.count', currentParamRules.length);
    }
  }

  function addParamRule() {
    const nameInput = document.getElementById("param-rule-name-input");
    const matchSelect = document.getElementById("param-rule-match");
    const valueInput = document.getElementById("param-rule-value-input");
    const actionSelect = document.getElementById("param-rule-action");

    const paramName = nameInput.value.trim();
    const value = valueInput.value.trim();

    if (!paramName) {
      alert(t("msg.input_param_name"));
      return;
    }
    if (!value) {
      alert(t("msg.input_param_value"));
      return;
    }

    const rule = {
      param_name: paramName,
      match_type: matchSelect.value,
      value: value,
      action: actionSelect.value
    };

    currentParamRules.push(rule);
    refreshParamRuleTable();
    nameInput.value = "";
    valueInput.value = "";
    nameInput.focus();
  }

  function deleteParamRule(index) {
    if (index >= 0 && index < currentParamRules.length) {
      currentParamRules.splice(index, 1);
      refreshParamRuleTable();
    }
  }

  function saveParamRules() {
    fetch('/updateparamrules', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(currentParamRules)
    })
      .then(response => {
        if (response.ok) {
          alert(t('msg.param_saved', currentParamRules.length));
        } else {
          alert(t('msg.save_failed'));
        }
      })
      .catch(error => {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  }

  let paramRuleEventsInited = false;

  function initParamRuleEvents() {
    if (paramRuleEventsInited) return;
    paramRuleEventsInited = true;

    const addBtn = document.getElementById("param-rule-add-btn");
    if (addBtn) {
      addBtn.addEventListener("click", addParamRule);
    }

    const saveBtn = document.getElementById("param-rule-save-btn");
    if (saveBtn) {
      saveBtn.addEventListener("click", saveParamRules);
    }

    const nameInput = document.getElementById("param-rule-name-input");
    if (nameInput) {
      nameInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          addParamRule();
        }
      });
    }

    const valueInput = document.getElementById("param-rule-value-input");
    if (valueInput) {
      valueInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          addParamRule();
        }
      });
    }

    const tableBody = document.getElementById("param-rule-table-body");
    if (tableBody) {
      tableBody.addEventListener("click", function (event) {
        const target = event.target.closest("button[data-action='delete-param-rule']");
        if (!target) return;
        const index = parseInt(target.dataset.index, 10);
        if (!isNaN(index)) {
          deleteParamRule(index);
        }
      });
    }
  }

  // Method rules

  function renderMethodTags() {
    const wrap = document.getElementById("method-tags-wrap");
    const emptyHint = document.getElementById("method-empty-hint");
    const countEl = document.getElementById("method-count");
    if (!wrap) return;

    // Clear old tags, keep empty hint
    wrap.querySelectorAll(".method-tag").forEach(el => el.remove());
    if (emptyHint) {
      emptyHint.style.display = currentMethods.length ? "none" : "inline";
    }

    currentMethods.forEach((method, index) => {
      const tag = document.createElement("span");
      tag.className = "method-tag";
      tag.innerHTML = `
        ${escapeHtml(method)}
        <button type="button" class="method-tag-remove" data-action="delete-method" data-index="${index}" title="' + t('common.delete') + '">&times;</button>
      `;
      wrap.appendChild(tag);
    });

    if (countEl) {
      countEl.textContent = t('method.count', currentMethods.length);
    }
  }

  function addMethod() {
    const input = document.getElementById("method-input");
    if (!input) return;
    const value = input.value.trim();
    if (!value) {
      alert(t("msg.input_method"));
      return;
    }
    if (!/^[A-Za-z]+$/.test(value)) {
      alert(t("msg.method_invalid_char"));
      return;
    }
    const upper = value.toUpperCase();
    if (currentMethods.includes(upper)) {
      alert(t('msg.method_exists', upper));
      return;
    }
    currentMethods.push(upper);
    renderMethodTags();
    input.value = "";
    input.focus();
  }

  function deleteMethod(index) {
    if (index >= 0 && index < currentMethods.length) {
      currentMethods.splice(index, 1);
      renderMethodTags();
    }
  }

  function fetchMethods() {
    fetch('/getmethodlist')
      .then(response => response.json())
      .then(data => {
        currentMethods = Array.isArray(data.methmodlist) ? data.methmodlist.filter(Boolean) : [];
        renderMethodTags();
      })
      .catch(error => {
        console.error('Error fetching method list:', error);
        currentMethods = [];
        renderMethodTags();
      });
  }

  function saveMethods() {
    fetch('/updatemethodlist', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ method_list: currentMethods })
    })
      .then(response => {
        if (response.ok) {
          alert(t('msg.method_saved', currentMethods.length));
        } else {
          alert(t('msg.save_failed'));
        }
      })
      .catch(error => {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  }

  let methodRuleEventsInited = false;

  function initMethodRuleEvents() {
    if (methodRuleEventsInited) return;
    methodRuleEventsInited = true;

    const addBtn = document.getElementById("method-add-btn");
    if (addBtn) {
      addBtn.addEventListener("click", addMethod);
    }

    const saveBtn = document.getElementById("method-save-btn");
    if (saveBtn) {
      saveBtn.addEventListener("click", saveMethods);
    }

    const input = document.getElementById("method-input");
    if (input) {
      input.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          addMethod();
        }
      });
    }

    // Tag delete button event delegation
    const tagsWrap = document.getElementById("method-tags-wrap");
    if (tagsWrap) {
      tagsWrap.addEventListener("click", function (event) {
        const target = event.target.closest("button[data-action='delete-method']");
        if (!target) return;
        const index = parseInt(target.dataset.index, 10);
        if (!isNaN(index)) {
          deleteMethod(index);
        }
      });
    }
  }

  // Anti-scan status code mgmt

  // Drag-select state
  let scanCodeSelected = new Set();
  let scanCodeDragState = null; // { startX, startY } | null

  function renderScanCodeTags() {
    const wrap = document.getElementById("scan-code-tags-wrap");
    const emptyHint = document.getElementById("scan-code-empty-hint");
    const countEl = document.getElementById("scan-code-count");
    const delSelBtn = document.getElementById("scan-code-delete-sel-btn");
    if (!wrap) return;

    // Clear old tags
    wrap.querySelectorAll(".method-tag").forEach(el => el.remove());

    currentScanCodes.forEach((code, index) => {
      const tag = document.createElement("span");
      tag.className = "method-tag";
      tag.dataset.index = index;
      if (scanCodeSelected.has(index)) {
        tag.classList.add("selected");
      }
      tag.innerHTML = `
        ${escapeHtml(code)}
        <button type="button" class="method-tag-remove" data-action="delete-scan-code" data-index="${index}" title="' + t('common.delete') + '">&times;</button>
      `;
      wrap.appendChild(tag);
    });

    if (countEl) {
      countEl.textContent = t('antiscan.code_count', currentScanCodes.length);
    }
    if (delSelBtn) {
      delSelBtn.style.display = scanCodeSelected.size > 0 ? "" : "none";
    }
  }

  function addScanCode() {
    const input = document.getElementById("scan-code-input");
    if (!input) return;
    const value = input.value.trim();
    if (!value) {
      alert(t("msg.code_input"));
      return;
    }

    // Parse range input 501-507
    const rangeMatch = value.match(/^(\d+)-(\d+)$/);
    if (rangeMatch) {
      const start = parseInt(rangeMatch[1], 10);
      const end = parseInt(rangeMatch[2], 10);
      if (start > end) {
        alert(t("msg.code_range_invalid"));
        return;
      }
      if (end - start > 500) {
        alert(t("msg.code_range_too_large"));
        return;
      }
      const toAdd = [];
      for (let i = start; i <= end; i++) {
        const code = String(i);
        if (!currentScanCodes.includes(code)) {
          toAdd.push(code);
        }
      }
      if (toAdd.length === 0) {
        alert(t("msg.code_range_empty"));
        return;
      }
      currentScanCodes.push(...toAdd);
      // Sort after range add
      currentScanCodes.sort((a, b) => parseInt(a, 10) - parseInt(b, 10));
      renderScanCodeTags();
      input.value = "";
      input.focus();
      return;
    }

    // Single status code
    if (!/^\d+$/.test(value)) {
      alert(t("msg.code_invalid"));
      return;
    }
    if (currentScanCodes.includes(value)) {
      alert(t("msg.code_exists", value));
      return;
    }
    currentScanCodes.push(value);
    // Sort after single add
    currentScanCodes.sort((a, b) => parseInt(a, 10) - parseInt(b, 10));
    renderScanCodeTags();
    input.value = "";
    input.focus();
  }

  function deleteScanCode(index) {
    if (index >= 0 && index < currentScanCodes.length) {
      currentScanCodes.splice(index, 1);
      scanCodeSelected.delete(index);
      // Fix selected indexes
      const updated = new Set();
      scanCodeSelected.forEach(i => {
        updated.add(i > index ? i - 1 : i);
      });
      scanCodeSelected = updated;
      renderScanCodeTags();
    }
  }

  function deleteSelectedScanCodes() {
    if (scanCodeSelected.size === 0) return;
    const indices = Array.from(scanCodeSelected).sort((a, b) => b - a); // Descending
    indices.forEach(i => currentScanCodes.splice(i, 1));
    scanCodeSelected = new Set();
    renderScanCodeTags();
  }

  function toggleTagSelection(index) {
    if (scanCodeSelected.has(index)) {
      scanCodeSelected.delete(index);
    } else {
      scanCodeSelected.add(index);
    }
    renderScanCodeTags();
  }

  // Drag-select logic

  function getTagsWrap() {
    return document.getElementById("scan-code-tags-wrap");
  }

  function getSelectionRect() {
    let el = document.getElementById("scan-code-selection-rect");
    if (!el) {
      el = document.createElement("div");
      el.id = "scan-code-selection-rect";
      el.className = "selection-rect";
      document.body.appendChild(el);
    }
    return el;
  }

  function startDragSelection(e) {
    // Start only in tags-wrap, not on delete btn
    const wrap = getTagsWrap();
    if (!wrap) return;
    if (e.target.closest(".method-tag-remove")) return;
    if (!wrap.contains(e.target) && e.target !== wrap) return;

    const rect = wrap.getBoundingClientRect();
    scanCodeDragState = {
      startX: e.clientX,
      startY: e.clientY,
      wrapLeft: rect.left,
      wrapTop: rect.top
    };
  }

  function updateDragSelection(e) {
    if (!scanCodeDragState) return;
    const selRect = getSelectionRect();
    const x1 = scanCodeDragState.startX;
    const y1 = scanCodeDragState.startY;
    const x2 = e.clientX;
    const y2 = e.clientY;

    selRect.style.left = Math.min(x1, x2) + "px";
    selRect.style.top = Math.min(y1, y2) + "px";
    selRect.style.width = Math.abs(x2 - x1) + "px";
    selRect.style.height = Math.abs(y2 - y1) + "px";
    selRect.style.display = "block";
  }

  function endDragSelection(e) {
    if (!scanCodeDragState) return;
    const selRect = getSelectionRect();
    selRect.style.display = "none";

    // Calculate selection area
    const x1 = Math.min(scanCodeDragState.startX, e.clientX);
    const y1 = Math.min(scanCodeDragState.startY, e.clientY);
    const x2 = Math.max(scanCodeDragState.startX, e.clientX);
    const y2 = Math.max(scanCodeDragState.startY, e.clientY);

    // Check which tags are in selection
    const wrap = getTagsWrap();
    if (!wrap) { scanCodeDragState = null; return; }
    const tags = wrap.querySelectorAll(".method-tag");
    tags.forEach(tag => {
      const r = tag.getBoundingClientRect();
      // Select if tag intersects selection rect
      if (!(r.right < x1 || r.left > x2 || r.bottom < y1 || r.top > y2)) {
        const index = parseInt(tag.dataset.index, 10);
        if (!isNaN(index)) {
          scanCodeSelected.add(index);
        }
      }
    });

    scanCodeDragState = null;
    renderScanCodeTags();
  }

  function clearScanCodeSelection() {
    scanCodeSelected = new Set();
    renderScanCodeTags();
  }

  function saveScanCodes() {
    const value = currentScanCodes.join(" ");
    fetch('/updateglobalconfig', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ cc_alerm_code: value })
    })
      .then(response => {
        if (response.ok) {
          alert(t('msg.scan_codes_saved', currentScanCodes.length));
        } else {
          alert(t('msg.save_failed'));
        }
      })
      .catch(error => {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  }

  let scanCodeEventsInited = false;

  function initScanCodeEvents() {
    if (scanCodeEventsInited) return;  // Dedup
    scanCodeEventsInited = true;

    const addBtn = document.getElementById("scan-code-add-btn");
    if (addBtn) {
      addBtn.addEventListener("click", addScanCode);
    }

    const saveBtn = document.getElementById("scan-code-save-btn");
    if (saveBtn) {
      saveBtn.addEventListener("click", saveScanCodes);
    }

    const delSelBtn = document.getElementById("scan-code-delete-sel-btn");
    if (delSelBtn) {
      delSelBtn.addEventListener("click", deleteSelectedScanCodes);
    }

    const input = document.getElementById("scan-code-input");
    if (input) {
      input.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          addScanCode();
        }
      });
    }

    // Tag click delegation: delete/select/drag
    const tagsWrap = document.getElementById("scan-code-tags-wrap");
    if (tagsWrap) {
      tagsWrap.addEventListener("click", function (event) {
        const removeBtn = event.target.closest("button[data-action='delete-scan-code']");
        if (removeBtn) {
          const index = parseInt(removeBtn.dataset.index, 10);
          if (!isNaN(index)) {
            deleteScanCode(index);
          }
          return;
        }
        // Click tag (not delete btn) toggles selection
        const tag = event.target.closest(".method-tag");
        if (tag && tag.dataset.index !== undefined) {
          const index = parseInt(tag.dataset.index, 10);
          if (!isNaN(index)) {
            toggleTagSelection(index);
          }
        }
      });

      // Drag-select: mousedown start
      tagsWrap.addEventListener("mousedown", function (e) {
        if (e.button !== 0) return; // Left button only
        startDragSelection(e);
      });
    }

    // Global mousemove/mouseup for drag-select
    document.addEventListener("mousemove", function (e) {
      if (!scanCodeDragState) return;
      updateDragSelection(e);
    });
    document.addEventListener("mouseup", function (e) {
      if (!scanCodeDragState) return;
      endDragSelection(e);
    });

    // Delete key removes selection
    document.addEventListener("keydown", function (e) {
      if (e.key === "Delete" && scanCodeSelected.size > 0) {
        // Only respond when anti-scan is visible
        const panel = document.getElementById("anti-scan");
        if (panel && !panel.classList.contains("hidden")) {
          e.preventDefault();
          deleteSelectedScanCodes();
        }
      }
      // Escape clears selection
      if (e.key === "Escape" && scanCodeSelected.size > 0) {
        const panel = document.getElementById("anti-scan");
        if (panel && !panel.classList.contains("hidden")) {
          e.preventDefault();
          clearScanCodeSelection();
        }
      }
    });

    // Click outside clears selection
    document.addEventListener("click", function (e) {
      if (scanCodeSelected.size === 0) return;
      const panel = document.getElementById("anti-scan");
      if (!panel || panel.classList.contains("hidden")) return;
      const tagsWrap = document.getElementById("scan-code-tags-wrap");
      // Click outside tag area clears selection
      if (tagsWrap && !tagsWrap.contains(e.target) && !e.target.closest("#scan-code-delete-sel-btn")) {
        clearScanCodeSelection();
      }
    });
  }

  function renderHttpLogTable(logs) {
    currentHttpLogs = logs;
    // Clamp to valid range
    var totalPages = getLogTotalPages();
    if (logCurrentPage > totalPages) logCurrentPage = totalPages;
    if (logCurrentPage < 1) logCurrentPage = 1;

    var start = (logCurrentPage - 1) * logPageSize;
    var pageLogs = logs.slice(start, start + logPageSize);

    const body = document.getElementById("log-table-body");
    if (!body) return;
    body.innerHTML = "";
    if (!pageLogs.length) {
      body.innerHTML = '<tr><td colspan="9">' + t('log.no_logs') + '</td></tr>';
      renderLogPagination();
      return;
    }

    pageLogs.forEach((item, index) => {
      // Parse content JSON
      var entry = null;
      try { entry = JSON.parse(item.content); } catch (e) {}
      var method = entry ? (entry.method || '') : '';
      var country = (entry && entry.geo) ? (entry.geo.country || '') : '';
      var province = item.geo || '';
      var uriArgs = entry ? entry.uri_args : null;
      // Cache parsed fields for event handlers
      item._method = method;
      item._uriArgs = uriArgs;
      item._wafRules = (entry && entry.waf_rules) ? entry.waf_rules : [];

      // Format geo as "country-province"
      var geoDisplay = '-';
      if (country && province) {
        geoDisplay = country + '-' + province;
      } else if (country) {
        geoDisplay = country;
      } else if (province) {
        geoDisplay = province;
      }

      var pathText = item.path || '';

      var hasArgs = uriArgs && typeof uriArgs === 'object' && Object.keys(uriArgs).length > 0;

      const row = document.createElement("tr");
      row.innerHTML = `
        <td class="col-logid" title="${escapeHtml(item.logId)}">${escapeHtml(item.logId)}</td>
        <td class="col-srcip">${escapeHtml(item.sourceIp)}</td>
        <td class="col-geo">${escapeHtml(geoDisplay)}</td>
        <td class="col-path" title="${escapeHtml(pathText)}">${escapeHtml(pathText)}</td>
        <td class="col-method">${escapeHtml(method)}</td>
        <td class="col-params">
          ${hasArgs ? '<button type="button" class="btn btn-outline btn-sm" data-action="show-params" data-index="' + index + '">参数</button>' : '<span class="log-no-args">-</span>'}
        </td>
        <td class="col-time">${escapeHtml(item.time)}</td>
        <td class="col-status">${item.blocked ? '<button type="button" class="waf-status-tag block" data-action="show-waf-rules" data-index="' + index + '">' + t('log.status_blocked') + '</button>' : (item._wafRules && item._wafRules.length ? '<button type="button" class="waf-status-tag alert" data-action="show-waf-rules" data-index="' + index + '">' + t('log.status_alert') + '</button>' : '<span class="waf-status-tag pass">' + t('log.status_normal') + '</span>')}</td>
        <td class="col-action">
          <button type="button" class="btn btn-outline btn-sm" data-action="view-log" data-index="${index}">${t('common.view')}</button>
        </td>
      `;
      body.appendChild(row);
    });
    renderLogPagination();
  }

  // Log pagination control

  function renderLogPagination() {
    var totalPages = getLogTotalPages();
    var infoEl = document.getElementById('log-page-info');
    var jumpEl = document.getElementById('log-page-jump');
    var sizeEl = document.getElementById('log-page-size');

    if (infoEl) {
      infoEl.textContent = t('log.page_info', logCurrentPage, totalPages, currentHttpLogs.length);
    }
    if (jumpEl) {
      jumpEl.max = totalPages;
    }
    if (sizeEl && parseInt(sizeEl.value, 10) !== logPageSize) {
      sizeEl.value = logPageSize;
    }

    // Update button states
    var firstBtn = document.getElementById('log-page-first');
    var prevBtn = document.getElementById('log-page-prev');
    var nextBtn = document.getElementById('log-page-next');
    var lastBtn = document.getElementById('log-page-last');

    if (firstBtn) firstBtn.disabled = logCurrentPage <= 1;
    if (prevBtn) prevBtn.disabled = logCurrentPage <= 1;
    if (nextBtn) nextBtn.disabled = logCurrentPage >= totalPages;
    if (lastBtn) lastBtn.disabled = logCurrentPage >= totalPages;
  }

  function goToLogPage(page) {
    var totalPages = getLogTotalPages();
    page = parseInt(page, 10);
    if (isNaN(page) || page < 1) page = 1;
    if (page > totalPages) page = totalPages;
    logCurrentPage = page;
    renderHttpLogTable(currentHttpLogs);
  }

  function changeLogPageSize(newSize) {
    newSize = parseInt(newSize, 10);
    if (isNaN(newSize) || newSize < 1) newSize = 20;
    logPageSize = newSize;
    logCurrentPage = 1;
    renderHttpLogTable(currentHttpLogs);
  }

  function fetchHttpLogs() {
    const sourceIp = document.getElementById("filter-source-ip").value.trim();
    const logId = document.getElementById("filter-log-id").value.trim();
    const pattern = document.getElementById("filter-path").value.trim();
    const startTime = document.getElementById("filter-start-time").value;
    const endTime = document.getElementById("filter-end-time").value;

    const params = new URLSearchParams();
    if (sourceIp) params.set("source_ip", sourceIp);
    if (logId) params.set("log_id", logId);
    if (startTime) params.set("starttime", startTime);
    if (endTime) params.set("endtime", endTime);
    params.set("limit", "1000");

    logCurrentPage = 1; // Reset to first page on new fetch

    fetch("/querylogs?" + params.toString())
      .then(function (res) { return res.json(); })
      .then(function (data) {
        currentHttpLogs = data.logs || [];
        httpLogTotal = data.total || 0;
        renderHttpLogTable(currentHttpLogs);
      })
      .catch(function (err) {
        console.error("Fetch logs failed:", err);
        currentHttpLogs = [];
        renderHttpLogTable([]);
      });
  }

  function filterHttpLogs() {
    // Server query mode: all filters sent to backend
    fetchHttpLogs();
  }

  function clearHttpFilters() {
    document.getElementById("filter-source-ip").value = "";
    document.getElementById("filter-log-id").value = "";
    document.getElementById("filter-path").value = "";
    document.getElementById("filter-province").value = "";
    document.getElementById("filter-start-time").value = "";
    document.getElementById("filter-end-time").value = "";
    fetchHttpLogs();
  }

  // Request params modal

  function openParamDetail(record) {
    const modal = document.getElementById("log-param-modal");
    const body = document.getElementById("log-param-content");
    if (!modal || !body) return;

    var text = '';
    // Use cached _uriArgs, or parse content
    var uriArgs = (record && record._uriArgs) ? record._uriArgs : null;
    if (!uriArgs && record && record.content) {
      try { var e = JSON.parse(record.content); uriArgs = e.uri_args; } catch (ex) {}
    }
    if (uriArgs && typeof uriArgs === 'object') {
      var keys = Object.keys(uriArgs);
      if (keys.length > 0) {
        keys.forEach(function (k) {
          var v = uriArgs[k];
          text += k + ': ' + (v === null || v === undefined ? '' : String(v)) + '\n';
        });
      } else {
        text = t('log.empty_params');
      }
    } else {
      text = t('log.empty_params');
    }
    body.textContent = text;
    modal.classList.remove("hidden");
  }

  function closeParamDetail() {
    const modal = document.getElementById("log-param-modal");
    if (!modal) return;
    modal.classList.add("hidden");
  }

  // Block info drawer

  function openWafRulesDrawer(record) {
    const overlay = document.getElementById("log-drawer-overlay");
    const body = document.getElementById("log-drawer-content");
    const title = document.getElementById("log-drawer-title");
    if (!overlay || !body) return;

    if (title) title.textContent = t('log.drawer_block_title');

    var text = '';
    var rules = (record && record._wafRules) ? record._wafRules : null;
    // Fallback parse content
    if (!rules && record && record.content) {
      try { var e = JSON.parse(record.content); rules = e.waf_rules || []; } catch (ex) {}
    }

    if (rules && rules.length > 0) {
      var lines = [];
      lines.push(t('log.drawer_intro'));
      lines.push('');
      rules.forEach(function (r, i) {
        if (typeof r === 'object') {
          lines.push('  ' + (i + 1) + '. [Rule ID: ' + (r.rule_id || '-') + '] ' + (r.description || ''));
          if (r.hit_location) lines.push('     ' + t('log.drawer_hit_location') + ': ' + r.hit_location);
          if (r.time) lines.push('     ' + t('log.drawer_hit_time') + ': ' + r.time);
        } else {
          lines.push('  ' + (i + 1) + '. ' + r);
        }
      });
      text = lines.join('\n');
    } else {
      text = t('log.drawer_no_rules');
    }

    body.textContent = text;
    overlay.classList.remove("hidden");
    document.body.style.overflow = 'hidden';
  }

  // Request detail drawer

  function openLogDrawer(record) {
    const overlay = document.getElementById("log-drawer-overlay");
    const body = document.getElementById("log-drawer-content");
    const title = document.getElementById("log-drawer-title");
    if (!overlay || !body) return;

    if (title) title.textContent = t('log.drawer_title');

    var text = '';
    if (record && record.content) {
      try {
        var entry = JSON.parse(record.content);
        var lines = [];
        lines.push(t('log.drawer_basic_info'));
        lines.push(t('log.drawer_log_id') + ': ' + (entry.log_id || '-'));
        lines.push(t('log.drawer_client_ip') + ': ' + (entry.client_ip || '-'));
        lines.push(t('log.drawer_remote_addr') + ': ' + (entry.remote_addr || '-') + ':' + (entry.remote_port || '-'));
        lines.push(t('log.drawer_method') + ': ' + (entry.method || '-'));
        lines.push(t('log.drawer_uri') + ': ' + (entry.uri || '-'));
        if (entry.query_string) lines.push(t('log.drawer_query_string') + ': ' + entry.query_string);
        lines.push(t('log.drawer_timestamp') + ': ' + (entry.timestamp || '-'));
        lines.push(t('log.drawer_status') + ': ' + (entry.status || '-'));
        lines.push(t('log.drawer_waf_status') + ': ' + (entry.blocked ? t('log.status_blocked') : t('log.status_normal')));
        lines.push(t('log.drawer_request_time') + ': ' + (entry.request_time || '-') + 's');
        lines.push(t('log.drawer_request_length') + ': ' + (entry.request_length || '-'));

        if (entry.geo) {
          lines.push('');
          lines.push(t('log.drawer_geo_section'));
          lines.push(t('log.drawer_country') + ': ' + (entry.geo.country || '-'));
          lines.push(t('log.drawer_province') + ': ' + (entry.geo.region || '-'));
          lines.push(t('log.drawer_continent') + ': ' + (entry.geo.continent || '-'));
        }

        if (entry.uri_args && typeof entry.uri_args === 'object') {
          var argKeys = Object.keys(entry.uri_args);
          if (argKeys.length > 0) {
            lines.push('');
            lines.push(t('log.drawer_uri_args'));
            argKeys.forEach(function (k) {
              lines.push('  ' + k + ': ' + (entry.uri_args[k] === null ? '' : String(entry.uri_args[k])));
            });
          }
        }

        if (entry.headers && typeof entry.headers === 'object') {
          var hdrKeys = Object.keys(entry.headers);
          if (hdrKeys.length > 0) {
            lines.push('');
            lines.push(t('log.drawer_headers'));
            hdrKeys.forEach(function (k) {
              lines.push('  ' + k + ': ' + (entry.headers[k] === null ? '' : String(entry.headers[k])));
            });
          }
        }

        if (entry.post_args && typeof entry.post_args === 'object') {
          var postKeys = Object.keys(entry.post_args);
          if (postKeys.length > 0) {
            lines.push('');
            lines.push(t('log.drawer_post_args'));
            postKeys.forEach(function (k) {
              lines.push('  ' + k + ': ' + (entry.post_args[k] === null ? '' : String(entry.post_args[k])));
            });
          }
        }

        if (entry.body) {
          lines.push('');
          lines.push(t('log.drawer_body'));
          lines.push(String(entry.body));
        }

        text = lines.join('\n');
      } catch (e) {
        text = record.content;
      }
    } else {
      text = t('log.drawer_no_content');
    }

    body.textContent = text;
    overlay.classList.remove("hidden");
    // Lock main scroll, drawer only
    document.body.style.overflow = 'hidden';
  }

  function closeLogDrawer() {
    const overlay = document.getElementById("log-drawer-overlay");
    if (!overlay) return;
    overlay.classList.add("hidden");
    // Restore main scroll
    document.body.style.overflow = '';
  }

  let httpLogEventsInited = false;

  function initHttpLogEvents() {
    if (httpLogEventsInited) return;  // Dedup
    httpLogEventsInited = true;

    document.getElementById("filter-log").addEventListener("click", filterHttpLogs);
    document.getElementById("clear-log").addEventListener("click", clearHttpFilters);
    // Manual refresh
    const refreshLogBtn = document.getElementById("refresh-log");
    if (refreshLogBtn) refreshLogBtn.addEventListener("click", fetchHttpLogs);

    // Table button event delegation
    document.getElementById("log-table-body").addEventListener("click", function (event) {
      const target = event.target.closest("button[data-action]");
      if (!target) return;
      const action = target.dataset.action;
      const pageIdx = Number(target.dataset.index);
      // Map page-level index to global index
      const globalIdx = (logCurrentPage - 1) * logPageSize + pageIdx;
      const record = currentHttpLogs[globalIdx];
      if (!record) return;
      if (action === "view-log") {
        openLogDrawer(record);
      } else if (action === "show-params") {
        openParamDetail(record);
      } else if (action === "show-waf-rules") {
        openWafRulesDrawer(record);
      }
    });

    // Param modal close

    var paramModal = document.getElementById("log-param-modal");
    if (paramModal) {
      paramModal.querySelector(".modal-backdrop").addEventListener("click", closeParamDetail);
      var paramCloseBtn = document.getElementById("log-param-close");
      if (paramCloseBtn) paramCloseBtn.addEventListener("click", closeParamDetail);
    }

    // Detail drawer close

    var drawerOverlay = document.getElementById("log-drawer-overlay");
    if (drawerOverlay) {
      drawerOverlay.querySelector(".drawer-backdrop").addEventListener("click", closeLogDrawer);
      var drawerCloseBtn = document.getElementById("log-drawer-close");
      if (drawerCloseBtn) drawerCloseBtn.addEventListener("click", closeLogDrawer);
    }

    // Global keyboard close

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape") {
        var paramModal = document.getElementById("log-param-modal");
        if (paramModal && !paramModal.classList.contains("hidden")) {
          event.preventDefault();
          closeParamDetail();
          return;
        }
        var drawerOverlay = document.getElementById("log-drawer-overlay");
        if (drawerOverlay && !drawerOverlay.classList.contains("hidden")) {
          event.preventDefault();
          closeLogDrawer();
          return;
        }
      }
    });

    // Pagination events

    // Page size switch
    var pageSizeEl = document.getElementById("log-page-size");
    if (pageSizeEl) {
      pageSizeEl.addEventListener("change", function () {
        changeLogPageSize(this.value);
      });
    }

    // Pagination buttons
    var firstBtn = document.getElementById("log-page-first");
    var prevBtn = document.getElementById("log-page-prev");
    var nextBtn = document.getElementById("log-page-next");
    var lastBtn = document.getElementById("log-page-last");

    if (firstBtn) firstBtn.addEventListener("click", function () { goToLogPage(1); });
    if (prevBtn) prevBtn.addEventListener("click", function () { goToLogPage(logCurrentPage - 1); });
    if (nextBtn) nextBtn.addEventListener("click", function () { goToLogPage(logCurrentPage + 1); });
    if (lastBtn) lastBtn.addEventListener("click", function () { goToLogPage(getLogTotalPages()); });

    // Jump button
    var goBtn = document.getElementById("log-page-go");
    if (goBtn) {
      goBtn.addEventListener("click", function () {
        var jumpEl = document.getElementById("log-page-jump");
        if (jumpEl) goToLogPage(jumpEl.value);
      });
    }

    // Jump input enter
    var jumpEl = document.getElementById("log-page-jump");
    if (jumpEl) {
      jumpEl.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          goToLogPage(this.value);
        }
      });
    }
  }

  // Light blue to red heat gradient
  function getHeatColor(value, max) {
    const ratio = max === 0 ? 0 : Math.min(1, value / max);
    // Log scale for low-value distinction
    const r = Math.round(55 + ratio * 200);
    const g = Math.round(120 - ratio * 110);
    const b = Math.round(230 - ratio * 200);
    return `rgb(${r},${g},${b})`;
  }

  function renderProvinceList(data, maxValue) {
    const wrap = document.getElementById("province-list-wrap");
    if (!wrap) return;

    const entries = Object.entries(data)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 13);

    wrap.innerHTML = "";
    entries.forEach(([name, count]) => {
      const barPercent = maxValue === 0 ? 0 : Math.round((count / maxValue) * 100);
      const item = document.createElement("div");
      item.className = "province-list-item";
      item.innerHTML = `
        <span class="pl-name">${escapeHtml(name)}</span>
        <div class="pl-bar-wrap"><div class="pl-bar-fill" style="width:${barPercent}%"></div></div>
        <span class="pl-count">${count}</span>
      `;
      // Hover highlight province
      item.addEventListener("mouseenter", () => {
        highlightProvince(name);
      });
      item.addEventListener("mouseleave", () => {
        clearProvinceHighlight();
      });
      wrap.appendChild(item);
    });
  }

  function highlightProvince(name) {
    if (!chinaMapGeoLayer) return;
    chinaMapGeoLayer.eachLayer(function (l) {
      if (l._n === name) {
        l.setStyle({
          weight: 2.5,
          opacity: 1,
          color: '#b91c1c',
          fillColor: '#fecaca',
          fillOpacity: 0.9
        });
        l.bringToFront();
        if (!l.isTooltipOpen()) {
          const visits = provinceVisitsData[name];
          const tip = '<b>' + name + '</b><em>' + (visits !== undefined ? visits +  + ' ' : t('dashboard.no_visits')) + '</em>';
          l.setTooltipContent(tip).openTooltip();
        }
      }
    });
  }

  function clearProvinceHighlight() {
    if (!chinaMapGeoLayer) return;
    const values = Object.values(provinceVisitsData);
    const maxVal = values.length ? Math.max(...values) : 0;
    chinaMapGeoLayer.eachLayer(function (l) {
      l.closeTooltip();
      const visits = provinceVisitsData[l._n];
      var fill;
      var fillOpacity;
      if (visits !== undefined) {
        fill = getHeatColor(visits, maxVal);
        fillOpacity = 0.85;
      } else {
        var rgn = _provinceRegion[l._n];
        fill = rgn && _regionColors[rgn] ? _regionColors[rgn] : '#e0e0e0';
        fillOpacity = 0.5;
      }
      l.setStyle({
        weight: 0.8,
        opacity: 0.6,
        color: '#8899aa',
        fillColor: fill,
        fillOpacity: fillOpacity
      });
    });
  }

  function initChinaMap() {
    if (chinaMapInited) return;
    chinaMapInited = true;

    const container = document.getElementById("china-map-container");
    if (!container) return;

    chinaMap = L.map(container, {
      center: [35.5, 106],
      zoom: 20,
      minZoom: 3,
      maxZoom: 10,
      maxBounds: [[0, 60], [58, 150]],
      maxBoundsViscosity: 0.8,
      zoomControl: true,
      attributionControl: false
    });

    // Region color scheme
    var R = {
      '东北': { c: '#e3c878', m: '辽宁,吉林,黑龙江' },
      '华北': { c: '#d4a6c8', m: '北京,天津,河北,山西,内蒙古' },
      '华东': { c: '#b5d5a0', m: '上海,江苏,浙江,安徽,福建,江西,山东' },
      '华中': { c: '#f4b878', m: '河南,湖北,湖南' },
      '华南': { c: '#a8d8ea', m: '广东,广西,海南,香港,澳门' },
      '西南': { c: '#c8b8e0', m: '重庆,四川,贵州,云南,西藏' },
      '西北': { c: '#e8c4a0', m: '陕西,甘肃,青海,宁夏,新疆' },
      '台湾': { c: '#f0a0a0', m: '台湾' }
    };
    _regionColors = {};
    for (var rk in R) { _regionColors[rk] = R[rk].c; }
    _provinceRegion = {};
    for (var rk2 in R) { var ns = R[rk2].m.split(','); for (var i = 0; i < ns.length; i++) _provinceRegion[ns[i]] = rk2; }

    var hover = { weight: 2.5, opacity: 1, color: '#b71c1c', fillColor: '#ffcdd2', fillOpacity: 0.85 };
    var cache = {};
    var cur = null;
    var mouse = null;

    chinaMap.on('mousemove', function (e) { mouse = e.latlng; });

    function over(e) {
      var l = e.target, n = l._n || '—';
      var visits = provinceVisitsData[n];
      var tip = '<b>' + n + '</b>';
      if (visits !== undefined) {
        tip += '<em>' + visits + ' visits</em>';
      } else {
        tip += '<em>' + t('dashboard.no_visits') + '</em>';
      }
      l.setTooltipContent(tip).openTooltip(e.latlng);
      if (cur && cur !== l) { var s = cache[L.stamp(cur)]; if (s) cur.setStyle(s); }
      var id = L.stamp(l);
      if (!cache[id]) cache[id] = { weight: l.options.weight, opacity: l.options.opacity, color: l.options.color, fillColor: l.options.fillColor, fillOpacity: l.options.fillOpacity };
      l.setStyle(hover).bringToFront(); cur = l;
    }

    function out(e) {
      var l = e.target;
      // Only reset if still current highlighted layer
      if (cur !== l) return;
      l.closeTooltip();
      var s = cache[L.stamp(l)]; if (s) l.setStyle(s);
      cur = null;
    }

    fetch('data/map.geojson').then(function (r) { return r.json(); }).then(function (d) {
      var features = d.features.filter(function (f) { return (f.properties.admin || '').toLowerCase() === 'china'; });
      // Append HK/Macau
      features.push({ type: 'Feature', properties: { admin: 'China', name: '香港' }, geometry: { type: 'Polygon', coordinates: [[[114.35, 22.55], [114.37, 22.53], [114.33, 22.48], [114.28, 22.37], [114.22, 22.25], [114.17, 22.21], [114.05, 22.18], [113.92, 22.19], [113.84, 22.22], [113.80, 22.35], [113.82, 22.45], [113.86, 22.53], [113.98, 22.56], [114.18, 22.57], [114.35, 22.55]]] } });
      features.push({ type: 'Feature', properties: { admin: 'China', name: '澳门' }, geometry: { type: 'Polygon', coordinates: [[[113.57, 22.22], [113.59, 22.21], [113.59, 22.17], [113.56, 22.13], [113.54, 22.12], [113.52, 22.13], [113.52, 22.18], [113.54, 22.22], [113.57, 22.22]]] } });

      var vals = Object.values(provinceVisitsData);
      var mapMax = vals.length ? Math.max.apply(null, vals) : 0;

      chinaMapGeoLayer = L.geoJSON({ type: 'FeatureCollection', features: features }, {
        bubblingMouseEvents: false,
        style: function (f) {
          var n = f.properties.name;
          var visits = provinceVisitsData[n];
          if (visits !== undefined) {
            return { weight: 0.8, opacity: 0.6, color: '#8899aa', fillColor: getHeatColor(visits, mapMax), fillOpacity: 0.85 };
          }
          var rgn = _provinceRegion[n];
          var fill = rgn ? _regionColors[rgn] : '#e0e0e0';
          return { weight: 0.8, opacity: 0.6, color: '#8899aa', fillColor: fill, fillOpacity: 0.5 };
        },
        onEachFeature: function (f, l) {
          l._n = f.properties.name;
          // Disable SVG focus outline
          l.on('click', function (e) {
            L.DomEvent.preventDefault(e);
            L.DomEvent.stopPropagation(e);
          });
        }
      }).addTo(chinaMap);

      chinaMapGeoLayer.eachLayer(function (l) {
        l.bindTooltip('', { className: 'cn-tip', direction: 'top', offset: [0, -6], opacity: 1, sticky: true });
        l.on({ mouseover: over, mouseout: out });
        var orig = l.openTooltip.bind(l);
        l.openTooltip = function (latlng) { return orig(latlng || mouse); };
        var id = L.stamp(l); cache[id] = { weight: l.options.weight, opacity: l.options.opacity, color: l.options.color, fillColor: l.options.fillColor, fillOpacity: l.options.fillOpacity };
      });

      try { chinaMap.fitBounds(chinaMapGeoLayer.getBounds().pad(0.03)); } catch (e) { chinaMap.setView([35.5, 106], 4.5); }
    }).catch(function (e) { console.error('Map data load failed: ' + e.message); });

    // Defer invalidateSize to ensure container visible
    setTimeout(function () { if (chinaMap) chinaMap.invalidateSize(); }, 100);
  }

  // World map

  function getCountryName(englishName) {
    var key = 'country.' + englishName;
    var translated = t(key);
    // t() returns key in brackets if not found
    if (translated && translated.indexOf('[') === 0) return englishName;
    return translated || englishName;
  }

  function renderCountryList(data, maxValue) {
    var wrap = document.getElementById("province-list-wrap");
    if (!wrap) return;

    var entries = Object.entries(data)
      .sort(function(a, b) { return b[1] - a[1]; })
      .slice(0, 13);

    wrap.innerHTML = "";
    entries.forEach(function(e) {
      var name = getCountryName(e[0]);
      var count = e[1];
      var barPercent = maxValue === 0 ? 0 : Math.round((count / maxValue) * 100);
      var item = document.createElement("div");
      item.className = "province-list-item";
      item.innerHTML =
        '<span class="pl-name">' + escapeHtml(name) + '</span>' +
        '<div class="pl-bar-wrap"><div class="pl-bar-fill" style="width:' + barPercent + '%"></div></div>' +
        '<span class="pl-count">' + count + '</span>';
      wrap.appendChild(item);
    });
  }

  function initWorldMap() {
    if (worldMapInited) return;
    worldMapInited = true;

    var container = document.getElementById("china-map-container");
    if (!container) return;

    // Ensure chinaMap exists
    if (!chinaMap) {
      chinaMap = L.map(container, {
        center: [20, 0],
        zoom: 2,
        minZoom: 2,
        maxZoom: 8,
        zoomControl: true,
        attributionControl: false
      });
    }

    fetch('data/countries.geojson')
      .then(function(res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function(data) {
        worldMapData = data.features;

        function resetStyle(l) {
          var visits = countryVisitsData[l._n];
          if (visits !== undefined) {
            var values = Object.values(countryVisitsData);
            var maxVal = values.length ? Math.max.apply(null, values) : 0;
            l.setStyle({
              fillColor: getHeatColor(visits, maxVal),
              fillOpacity: 0.85,
              color: '#8899aa',
              weight: 0.8
            });
          } else {
            l.setStyle({
              color: '#4a9fd8',
              weight: 0.8,
              fillColor: 'transparent',
              fillOpacity: 0
            });
          }
        }

        worldMapGeoLayer = L.geoJSON({ type: 'FeatureCollection', features: worldMapData }, {
          style: {
            color: '#4a9fd8',
            weight: 0.8,
            fillColor: 'transparent',
            fillOpacity: 0
          },
          onEachFeature: function(feature, layer) {
            var name = feature.properties.name || '';
            layer._n = name;

            layer.bindTooltip('', {
              sticky: true,
              direction: 'top',
              offset: [0, -5],
              className: 'cn-tip'
            });

            // Disable click interactions
            ['click', 'dblclick', 'mousedown', 'touchstart'].forEach(function(evt) {
              layer.on(evt, function(e) {
                L.DomEvent.stop(e.originalEvent);
                L.DomEvent.stop(e);
              });
            });

            layer.on('mouseover', function(e) {
              if (_worldCurrentLayer && _worldCurrentLayer !== layer) {
                resetStyle(_worldCurrentLayer);
              }
              if (chinaMapGeoLayer && currentMapType === 'world') {
                // handled by layer swap
              }
              layer.setStyle({
                color: '#ff6b35',
                weight: 2,
                fillColor: 'rgba(255,107,53,0.15)',
                fillOpacity: 1
              });
              layer.bringToFront();
              _worldCurrentLayer = layer;
              // Update tooltip with visit count
              var visits = countryVisitsData[name];
              var tip = '<b>' + getCountryName(name) + '</b>';
              if (visits !== undefined) {
                tip += '<em>' + visits + ' visits</em>';
              }
              layer.setTooltipContent(tip).openTooltip(e.latlng);
            });

            layer.on('mouseout', function() {
              if (_worldCurrentLayer === layer) {
                resetStyle(layer);
                _worldCurrentLayer = null;
              }
            });
          }
        });

        // If currently on world view, show immediately
        if (currentMapType === 'world') {
          worldMapGeoLayer.addTo(chinaMap);
          try { chinaMap.setView([20, 0], 2); } catch(e) {}
        }
      })
      .catch(function(err) {
        console.error('Failed to load world map data: ' + err.message);
      });

    setTimeout(function() { if (chinaMap) chinaMap.invalidateSize(); }, 100);
  }

  async function fetchWorldVisits(startTime, endTime) {
    try {
      var url = '/getworldvisits?starttime=' + encodeURIComponent(startTime || '') + '&endtime=' + encodeURIComponent(endTime || '');
      var resp = await fetch(url);
      if (resp.ok) {
        var data = await resp.json();
        countryVisitsData = data;
      }
    } catch (e) {
      console.log('Failed to fetch country visit data: ' + e.message);
    }
  }

  function applyWorldHeatColors() {
    if (!worldMapGeoLayer) return;
    var values = Object.values(countryVisitsData);
    var maxVal = values.length ? Math.max.apply(null, values) : 0;

    worldMapGeoLayer.eachLayer(function(l) {
      var visits = countryVisitsData[l._n];
      if (visits !== undefined) {
        l.setStyle({
          fillColor: getHeatColor(visits, maxVal),
          fillOpacity: 0.85,
          color: '#8899aa',
          weight: 0.8
        });
      } else {
        l.setStyle({
          fillColor: 'transparent',
          fillOpacity: 0,
          color: '#4a9fd8',
          weight: 0.8
        });
      }
    });
  }

  function refreshWorldMapData() {
    var values = Object.values(countryVisitsData);
    var maxValue = values.length ? Math.max.apply(null, values) : 0;
    window._maxMapValue = maxValue;

    applyWorldHeatColors();
    renderCountryList(countryVisitsData, maxValue);

    // Update ranking header
    var header = document.getElementById("map-ranking-header");
    if (header) {
      header.setAttribute('data-i18n', 'dashboard.country_ranking');
      header.textContent = t('dashboard.country_ranking');
    }
  }

  function switchMapType(type) {
    if (type === currentMapType) return;
    currentMapType = type;

    var rankingHeader = document.getElementById("map-ranking-header");

    if (type === 'china') {
      // Restore China map bounds
      chinaMap.setMinZoom(3);
      chinaMap.setMaxZoom(10);
      chinaMap.setMaxBounds([[0, 60], [58, 150]]);
      chinaMap.options.maxBoundsViscosity = 0.8;

      // Switch to China map layer
      if (worldMapGeoLayer) {
        chinaMap.removeLayer(worldMapGeoLayer);
        _worldCurrentLayer = null;
      }
      if (chinaMapGeoLayer) {
        chinaMap.addLayer(chinaMapGeoLayer);
        try { chinaMap.fitBounds(chinaMapGeoLayer.getBounds().pad(0.03)); } catch(e) { chinaMap.setView([35.5, 106], 4.5); }
      }
      if (rankingHeader) {
        rankingHeader.setAttribute('data-i18n', 'dashboard.province_ranking');
        rankingHeader.textContent = t('dashboard.province_ranking');
      }
      renderProvinceList(provinceVisitsData, window._maxMapValue || 0);
      // Re-apply heat colors
      if (chinaMapGeoLayer) {
        var vals = Object.values(provinceVisitsData);
        var maxV = vals.length ? Math.max.apply(null, vals) : 0;
        chinaMapGeoLayer.eachLayer(function(l) {
          var visits = provinceVisitsData[l._n];
          if (visits !== undefined) {
            l.setStyle({ fillColor: getHeatColor(visits, maxV), fillOpacity: 0.85 });
          }
        });
      }
    } else if (type === 'world') {
      // Remove China-specific restrictions
      chinaMap.setMinZoom(2);
      chinaMap.setMaxZoom(8);
      chinaMap.setMaxBounds(null);
      chinaMap.options.maxBoundsViscosity = 0;

      // Switch to world map layer
      if (chinaMapGeoLayer) {
        chinaMap.removeLayer(chinaMapGeoLayer);
      }
      // Ensure chinaMap base is ready
      if (!chinaMap) {
        var container = document.getElementById("china-map-container");
        if (container) {
          chinaMap = L.map(container, {
            center: [20, 0],
            zoom: 2,
            minZoom: 2,
            maxZoom: 8,
            zoomControl: true,
            attributionControl: false
          });
        }
      }
      if (!worldMapInited) {
        initWorldMap();
        // Poll for GeoJSON load (up to 5s)
        var attempts = 0;
        var checkInterval = setInterval(function() {
          attempts++;
          if (worldMapGeoLayer) {
            clearInterval(checkInterval);
            chinaMap.addLayer(worldMapGeoLayer);
            chinaMap.setView([20, 0], 2);
            if (rankingHeader) {
              rankingHeader.setAttribute('data-i18n', 'dashboard.country_ranking');
              rankingHeader.textContent = t('dashboard.country_ranking');
            }
            refreshWorldMapData();
          } else if (attempts > 50) {
            clearInterval(checkInterval);
          }
        }, 100);
        return;
      }
      if (worldMapGeoLayer) {
        chinaMap.addLayer(worldMapGeoLayer);
        chinaMap.setView([20, 0], 2);
      }
      if (rankingHeader) {
        rankingHeader.setAttribute('data-i18n', 'dashboard.country_ranking');
        rankingHeader.textContent = t('dashboard.country_ranking');
      }
      refreshWorldMapData();
    }
  }

  // Memory name labels (i18n)
  var _MEM_KEYS = {
    iplist_black: t('mem.iplist_black'),
    iplist_white: t('mem.iplist_white'),
    access_number_iplist: t('mem.access_number_iplist'),
    cc_control_iplist: t('mem.cc_control_iplist'),
    region_list: t('mem.region_list'),
    access_region_list: t('mem.access_region_list'),
    signature_list: t('mem.signature_list'),
    path_rules_list: t('mem.path_rules_list'),
    header_rules_list: t('mem.header_rules_list'),
    param_rules_list: t('mem.param_rules_list'),
  };

  async function getMemoryStats() {
    try {
      var response = await fetch('/getdictinfo');
      if (!response.ok) throw new Error('Memory stats request failed');
      var memoryStats = await response.json();
      renderMemoryStats(memoryStats);
    } catch (error) {
      console.log(t("msg.mem_stats_failed"), error);
      renderMemoryStats({});
    }
  }

  function renderMemoryStats(memoryStats) {
    var tbody = document.getElementById("mem-table-body");
    if (!tbody) return;

    var entries = Object.entries(memoryStats);
    var order = ["iplist_black", "iplist_white", "access_number_iplist", "cc_control_iplist", "region_list", "access_region_list", "signature_list", "path_rules_list", "header_rules_list", "param_rules_list"];
    var known = {};
    var rest = [];
    entries.forEach(function (e) {
      var k = e[0];
      if (k === "_errors") return;
      if (order.indexOf(k) !== -1) known[k] = e[1];
      else rest.push(e);
    });
    rest.sort(function (a, b) { return a[0].localeCompare(b[0]); });

    tbody.innerHTML = "";

    var list = [];
    order.forEach(function (k) { if (known[k]) list.push([k, known[k]]); });
    list = list.concat(rest);

    if (list.length === 0) {
      tbody.innerHTML = '<tr><td colspan="4" class="empty-hint">' + t('common.no_data') + '</td></tr>';
      return;
    }

    list.forEach(function (e) {
      var key = e[0], item = e[1];
      var label = _MEM_KEYS[key] || key;
      var percent = item.total_memory === 0 ? 0 : Math.round((item.used_memory / item.total_memory) * 100);

      var tr = document.createElement("tr");
      tr.innerHTML =
        '<td><span class="mem-name">' + escapeHtml(label) + '</span></td>' +
        '<td><span class="mem-percent">' + percent + '%</span></td>' +
        '<td><span class="mem-usage">' + item.used_memory + ' / ' + item.total_memory + ' Mb</span></td>' +
        '<td><span class="mem-count">' + item.key_count + '</span></td>';
      tbody.appendChild(tr);
    });
  }

  async function getServerStatus() {
    try {
      var resp = await fetch('/getserverstatus');
      if (!resp.ok) throw new Error('Server status request failed');
      var data = await resp.json();
      renderServerStatus(data);
    } catch (e) {
      console.log(t("msg.server_status_failed", e.message));
    }
  }

  function renderServerStatus(data) {
    var el = document.getElementById("server-status-content");
    if (!el) return;

    var cpuColor = data.cpu > 80 ? '#dc2626' : data.cpu > 60 ? '#f59e0b' : '#2563eb';
    var memColor = data.mem_percent > 80 ? '#dc2626' : data.mem_percent > 60 ? '#f59e0b' : '#059669';

    el.innerHTML =
      '<div class="server-stat-item">' +
        '<div class="server-stat-label">' +
          '<span class="stat-name">CPU</span>' +
          '<span class="stat-value" style="color:' + cpuColor + '">' + data.cpu + '%</span>' +
        '</div>' +
        '<div class="server-stat-bar-wrap"><div class="server-stat-bar-fill cpu" style="width:' + data.cpu + '%"></div></div>' +
      '</div>' +
      '<div class="server-stat-item">' +
        '<div class="server-stat-label">' +
          '<span class="stat-name">' + t('dashboard.memory') + '</span>' +
          '<span class="stat-value" style="color:' + memColor + '">' + data.mem_percent + '%</span>' +
        '</div>' +
        '<div class="server-stat-bar-wrap"><div class="server-stat-bar-fill mem" style="width:' + data.mem_percent + '%"></div></div>' +
        '<div class="server-stat-meta">' +
          '<span>' + t('dashboard.used_mb', data.mem_used) + '</span>' +
          '<span>' + t('dashboard.total_mb', data.mem_total) + '</span>' +
        '</div>' +
      '</div>';
  }

  // Pinyin to Chinese province name
  var PINYIN_TO_CN = {
    Beijing: '北京', Shanghai: '上海', Guangdong: '广东', Taiwan: '台湾',
    Zhejiang: '浙江', Jiangsu: '江苏', Henan: '河南', Shandong: '山东',
    Hebei: '河北', Hunan: '湖南', Hubei: '湖北', Fujian: '福建',
    Anhui: '安徽', Liaoning: '辽宁', Heilongjiang: '黑龙江', Jilin: '吉林',
    Sichuan: '四川', Chongqing: '重庆', Yunnan: '云南', Jiangxi: '江西',
    Guangxi: '广西', Shaanxi: '陕西', Shanxi: '山西', 'Nei Mongol': '内蒙古',
    Guizhou: '贵州', Xinjiang: '新疆', Gansu: '甘肃', Hainan: '海南',
    Ningxia: '宁夏', Qinghai: '青海', Xizang: '西藏', Tianjin: '天津',
    Macau: '澳门', 'Hong Kong': '香港',
  };

  function pinyinDataToCn(data) {
    var out = {};
    for (var k in data) {
      if (Object.prototype.hasOwnProperty.call(data, k)) {
        var cn = PINYIN_TO_CN[k] || k;
        out[cn] = data[k];
      }
    }
    return out;
  }

  function initMapTimeRange() {
    var now = new Date();
    // Local ISO time format (avoid UTC offset)
    function toLocalISO(d) {
      var pad = function(n) { return n < 10 ? '0' + n : '' + n; };
      return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
        'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    var end = toLocalISO(now);
    var start = toLocalISO(new Date(now.getTime() - 2 * 3600 * 1000));
    var startEl = document.getElementById("map-start-time");
    var endEl = document.getElementById("map-end-time");
    if (startEl) startEl.value = start;
    if (endEl) endEl.value = end;
  }

  async function fetchChinaVisits(startTime, endTime) {
    try {
      var url = '/getchinavisits?starttime=' + encodeURIComponent(startTime || '') + '&endtime=' + encodeURIComponent(endTime || '');
      var resp = await fetch(url);
      if (resp.ok) {
        var data = await resp.json();
        provinceVisitsData = pinyinDataToCn(data);
      }
    } catch (e) {
      console.log(t("msg.china_visits_failed", e.message));
    }
  }

  function refreshMapData() {
    var values = Object.values(provinceVisitsData);
    var maxValue = values.length ? Math.max(...values) : 0;
    window._maxMapValue = maxValue;

    if (chinaMapGeoLayer) {
      chinaMapGeoLayer.eachLayer(function (l) {
        var visits = provinceVisitsData[l._n];
        if (visits !== undefined) {
          l.setStyle({
            fillColor: getHeatColor(visits, maxValue),
            fillOpacity: 0.85
          });
        }
      });
    }

    if (chinaMap) {
      setTimeout(function () { if (chinaMap) chinaMap.invalidateSize(); }, 150);
    }

    renderProvinceList(provinceVisitsData, maxValue);
  }

  var mapQueryInited = false;
  function initMapQueryEvents() {
    if (mapQueryInited) return;
    mapQueryInited = true;

    var btn = document.getElementById("map-query-btn");
    if (btn) {
      btn.addEventListener("click", async function () {
        var startEl = document.getElementById("map-start-time");
        var endEl = document.getElementById("map-end-time");
        var startTime = startEl ? startEl.value : '';
        var endTime = endEl ? endEl.value : '';

        if (currentMapType === 'world') {
          await fetchWorldVisits(startTime, endTime);
          refreshWorldMapData();
        } else {
          await fetchChinaVisits(startTime, endTime);
          refreshMapData();
        }
      });
    }
  }

  async function renderDashboard() {
    // Parallel load, non-blocking
    getServerStatus();
    getMemoryStats();

    initMapQueryEvents();

    // First load: init time range to 2h, fetch then init map
    initMapTimeRange();
    var startEl = document.getElementById("map-start-time");
    var endEl = document.getElementById("map-end-time");
    var startTime = startEl ? startEl.value : '';
    var endTime = endEl ? endEl.value : '';

    // Fetch both China and world data in parallel
    await Promise.all([
      fetchChinaVisits(startTime, endTime),
      fetchWorldVisits(startTime, endTime)
    ]);

    // Init China map (once)
    initChinaMap();

    // Preload world map (non-blocking)
    initWorldMap();

    // Update current map and list
    if (currentMapType === 'world') {
      refreshWorldMapData();
    } else {
      refreshMapData();
    }

    // Map type switch
    var mapTypeRadios = document.querySelectorAll('input[name="map-type"]');
    mapTypeRadios.forEach(function(radio) {
      radio.addEventListener('change', function() {
        if (this.checked) {
          switchMapType(this.value);
        }
      });
    });
  }

  function showPage(pageId) {
    pagePanels.forEach((panel) => {
      panel.classList.toggle("hidden", panel.id !== pageId);
    });
    pageTitle.textContent = t('page.' + pageId) || t('page.default');
    sidebarChildren.forEach((child) => {
      child.classList.toggle("active", child.dataset.page === pageId);
    });

    // Expand sidebar group for current page after refresh
    var activeChild = document.querySelector(".sidebar-child.active");
    if (activeChild) {
      var submenu = activeChild.closest(".sidebar-submenu");
      if (submenu) {
        var groupId = submenu.dataset.group;
        var groupBtn = document.querySelector('.sidebar-group[data-group="' + groupId + '"]');
        if (groupBtn) {
          groupBtn.setAttribute("aria-expanded", "true");
        }
        submenu.classList.remove("hidden");
      }
    }

    // Persist active page
    try { sessionStorage.setItem("activePage", pageId); } catch (e) {}

    // Reload data on page switch
    switch (pageId) {
      case "dashboard":
        renderDashboard();
        break;
      case "region-block":
        renderRegionBlockLists();
        break;
      case "black-white":
        renderBlackWhiteLists();
        break;
      case "rule-method":
        fetchMethods();
        initMethodRuleEvents();
        break;
      case "rule-path":
        renderPathRules();
        initPathRuleEvents();
        break;
      case "rule-headers":
        renderHeaderRules();
        initHeaderRuleEvents();
        break;
      case "rule-params":
        renderParamRules();
        initParamRuleEvents();
        break;
      case "anti-scan":
        initScanCodeEvents();
        fetchScanConfig();
        initScanConfigEvents();
        fetchCcBlockedIpList();
        break;
      case "rate-limit":
        renderRateLimit();
        fetchBlockedIpList();
        initLimitConfigEvents();
        break;
      case "system-params":
        renderSystemParams();
        break;
      case "http-log":
        fetchHttpLogs();
        initHttpLogEvents();
        break;
      case "rule-regex":
        fetchSignatureRules();
        initSignatureRuleEvents();
        break;
    }
  }

  sidebarGroups.forEach((group) => {
    group.addEventListener("click", function () {
      const target = this.dataset.group;
      const submenu = document.querySelector('.sidebar-submenu[data-group="' + target + '"]');
      const isCurrentlyHidden = submenu.classList.contains("hidden");
      // Collapse other groups
      document.querySelectorAll(".sidebar-submenu").forEach(function (sm) {
        sm.classList.add("hidden");
      });
      sidebarGroups.forEach(function (g) {
        g.setAttribute("aria-expanded", "false");
      });
      // Expand current group
      if (isCurrentlyHidden) {
        submenu.classList.remove("hidden");
        this.setAttribute("aria-expanded", "true");
      }
    });
  });

  sidebarChildren.forEach((child) => {
    child.addEventListener("click", function () {
      showPage(this.dataset.page);
    });
  });

  // Region block: save

  // Event delegation: save button
  document.addEventListener('click', function (event) {
    var btn = event.target.closest('[data-action="save-region"]');
    if (!btn) return;

    var groupName = btn.dataset.group;
    var prefixMap = { province: 'region_', country: 'country_', continent: 'continent_' };
    var prefix = prefixMap[groupName];
    if (!prefix) return;

    // Extract entries for this group
    var data = {};
    for (var key in currentRegionData) {
      if (currentRegionData.hasOwnProperty(key) && key.indexOf(prefix) === 0) {
        data[key] = currentRegionData[key];
      }
    }

    fetch('/updateaccesscontrol', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    })
      .then(function (response) {
        if (response.ok) {
          var groupLabel = t('region.add_' + groupName);
alert(t('msg.region_saved', groupLabel));
        } else {
          alert(t('msg.save_failed'));
        }
      })
      .catch(function (error) {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  });

  // Delegation: block/unblock toggle
  document.addEventListener('click', function (event) {
    var btn = event.target.closest('[data-action="toggle-region"]');
    if (!btn) return;

    var key = btn.dataset.key;
    var currentValue = parseInt(btn.dataset.value, 10);
    // Toggle: 0↔1
    currentRegionData[key] = currentValue === 0 ? 1 : 0;
    refreshRegionTables();
  });

  // Delegation: search input (200ms debounce)
  var regionSearchTimers = {};
  document.addEventListener('input', function (event) {
    var input = event.target.closest('.region-search');
    if (!input) return;
    var group = input.dataset.group;
    if (regionSearchTimers[group]) clearTimeout(regionSearchTimers[group]);
    regionSearchTimers[group] = setTimeout(function () {
      refreshRegionTables();
    }, 200);
  });

  const addRegionBtn = document.getElementById("open-region-add");
  const modal = document.getElementById("add-selector-modal");
  const cancelModal = document.getElementById("region-add-cancel");
  const confirmModal = document.getElementById("region-add-confirm");
  const regionInput = document.getElementById("region-ip-input");
  let currentRegionIpInfo = null;

  addRegionBtn.addEventListener("click", function () {
    const value = regionInput.value.trim();
    if (!value) {
      alert(t("msg.input_ip_first_query"));
      return;
    }
    if (!isValidIPv4(value)) {
      alert(t("msg.invalid_ip"));
      return;
    }

    fetchIpInfo(value)
      .then((data) => {
        currentRegionIpInfo = data;
        renderRegionIpInfo(data);
        modal.classList.remove("hidden");
      })
      .catch((error) => {
        console.error(error);
        alert(error.message || t('msg.ip_query_failed'));
      });
  });

  regionInput.addEventListener("input", function () {
    currentRegionIpInfo = null;
    renderRegionIpInfo();
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && !modal.classList.contains("hidden")) {
      modal.classList.add("hidden");
    }
  });

  cancelModal.addEventListener("click", function () {
    modal.classList.add("hidden");
  });

  confirmModal.addEventListener("click", function () {
    if (!currentRegionIpInfo) {
      alert(t("msg.no_region_info_first"));
      return;
    }

    var type = document.querySelector('input[name="region-type"]:checked').value;
    var prefixMap = { province: 'region_', country: 'country_', continent: 'continent_' };
    var prefix = prefixMap[type];
    var valueMap = {
      province: currentRegionIpInfo.region_name,
      country: currentRegionIpInfo.country_name,
      continent: currentRegionIpInfo.continent_code,
    };

    var optionValue = valueMap[type] || regionInput.value.trim();
    if (!optionValue) {
      alert(t("msg.no_region_info"));
      return;
    }

    // Set blocked status (value = 0)
    currentRegionData[prefix + optionValue] = 0;
    refreshRegionTables();

    regionInput.value = "";
    currentRegionIpInfo = null;
    renderRegionIpInfo();
    modal.classList.add("hidden");

    var typeLabel = t('region.add_' + type);
    alert(t('msg.region_add_success', optionValue, typeLabel));
  });

  // Black/white list: add/delete/save

  function toggleAllCheckboxes(className, checked) {
    var boxes = document.querySelectorAll('.' + className);
    for (var i = 0; i < boxes.length; i++) {
      boxes[i].checked = checked;
    }
  }

  function addIpsToList(type, inputId, stateArr, refreshFn) {
    var input = document.getElementById(inputId);
    var raw = input.value.trim();
    if (!raw) {
      alert(t('msg.input_ip_first'));
      return;
    }
    var items = raw.split(',').map(function (s) { return s.trim(); }).filter(Boolean);
    var added = 0;
    for (var i = 0; i < items.length; i++) {
      // Check IP not already present
      var exists = false;
      for (var j = 0; j < stateArr.length; j++) {
        var curIp = typeof stateArr[j] === 'string' ? stateArr[j] : stateArr[j].ip;
        if (curIp === items[i]) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        stateArr.push({ip: items[i], time: 0});
        added++;
      }
    }
    input.value = '';
    refreshFn();
    if (added === 0) {
      alert(t('msg.ip_exists'));
    }
  }

  function deleteSelectedIps(type, stateArr, refreshFn) {
    var checked = document.querySelectorAll('.' + type + '-row-check:checked');
    if (!checked.length) {
      alert(t('msg.select_ips_first'));
      return;
    }
    var ips = [];
    for (var i = 0; i < checked.length; i++) {
      ips.push(checked[i].dataset.ip);
    }
    var body = type === 'blacklist' ? { blacklist_ipaddr: ips } : { whitelist_ipaddr: ips };
    fetch('/ipdel', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    })
      .then(function (response) {
        if (response.ok) {
          // Remove from local state
          for (var i = stateArr.length - 1; i >= 0; i--) {
            var curIp = typeof stateArr[i] === 'string' ? stateArr[i] : stateArr[i].ip;
            if (ips.indexOf(curIp) !== -1) {
              stateArr.splice(i, 1);
            }
          }
          refreshFn();
          alert(t('msg.delete_success_record', ips.length));
        } else {
          alert(t('msg.delete_failed_retry'));
        }
      })
      .catch(function (error) {
        console.error('Error:', error);
        alert(t('msg.delete_failed_retry'));
      });
  }

  function saveIpList(type, stateArr) {
    var label = t('bw.' + type);
    // Extract IP strings for API
    var ips = stateArr.map(function (entry) {
      return typeof entry === 'string' ? entry : entry.ip;
    });
    var body = type === 'blacklist' ? { blacklist_ipaddr: ips } : { whitelist_ipaddr: ips };
    fetch('/updateiplist', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    })
      .then(function (response) {
        if (response.ok) {
          // Assign current time to new entries
          var now = Math.floor(Date.now() / 1000);
          for (var i = 0; i < stateArr.length; i++) {
            if (typeof stateArr[i] === 'object' && !stateArr[i].time) {
              stateArr[i].time = now;
            }
          }
          refreshBlackWhiteTables();
          alert(t('msg.bw_saved', label, ips.length));
        } else {
          alert(t('msg.save_failed'));
        }
      })
      .catch(function (error) {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  }

  var blacklistAddBtn = document.getElementById('blacklist-add-btn');
  if (blacklistAddBtn) {
    blacklistAddBtn.addEventListener('click', function () {
      addIpsToList('blacklist', 'blacklist-input', currentBlacklist, refreshBlackWhiteTables);
    });
  }

  var whitelistAddBtn = document.getElementById('whitelist-add-btn');
  if (whitelistAddBtn) {
    whitelistAddBtn.addEventListener('click', function () {
      addIpsToList('whitelist', 'whitelist-input', currentWhitelist, refreshBlackWhiteTables);
    });
  }

  var blacklistDeleteBtn = document.getElementById('blacklist-delete-btn');
  if (blacklistDeleteBtn) {
    blacklistDeleteBtn.addEventListener('click', function () {
      deleteSelectedIps('blacklist', currentBlacklist, refreshBlackWhiteTables);
    });
  }

  var whitelistDeleteBtn = document.getElementById('whitelist-delete-btn');
  if (whitelistDeleteBtn) {
    whitelistDeleteBtn.addEventListener('click', function () {
      deleteSelectedIps('whitelist', currentWhitelist, refreshBlackWhiteTables);
    });
  }

  var blacklistSaveBtn = document.getElementById('blacklist-save-btn');
  if (blacklistSaveBtn) {
    blacklistSaveBtn.addEventListener('click', function () {
      saveIpList('blacklist', currentBlacklist);
    });
  }

  var whitelistSaveBtn = document.getElementById('whitelist-save-btn');
  if (whitelistSaveBtn) {
    whitelistSaveBtn.addEventListener('click', function () {
      saveIpList('whitelist', currentWhitelist);
    });
  }

  var blacklistSelectAll = document.getElementById('blacklist-select-all');
  if (blacklistSelectAll) {
    blacklistSelectAll.addEventListener('change', function () {
      toggleAllCheckboxes('blacklist-row-check', this.checked);
    });
  }

  var whitelistSelectAll = document.getElementById('whitelist-select-all');
  if (whitelistSelectAll) {
    whitelistSelectAll.addEventListener('change', function () {
      toggleAllCheckboxes('whitelist-row-check', this.checked);
    });
  }

  // Enter key in textareas triggers add
  var blacklistInput = document.getElementById('blacklist-input');
  if (blacklistInput) {
    blacklistInput.addEventListener('keydown', function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        addIpsToList('blacklist', 'blacklist-input', currentBlacklist, refreshBlackWhiteTables);
      }
    });
  }

  var whitelistInput = document.getElementById('whitelist-input');
  if (whitelistInput) {
    whitelistInput.addEventListener('keydown', function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        addIpsToList('whitelist', 'whitelist-input', currentWhitelist, refreshBlackWhiteTables);
      }
    });
  }

  // Rate limit config
  const limitSettings = document.getElementById("limit-settings");
  const limitPermanent = document.getElementById("limit-permanent");
  const limitTimed = document.getElementById("limit-timed");
  const limitDisconnect = document.getElementById("limit-disconnect");

  function updateLimitSection() {
    var enabledRadio = document.querySelector("input[name='limit-enabled']:checked");
    if (!enabledRadio || !limitSettings) return;
    var enabled = enabledRadio.value;
    limitSettings.classList.toggle("hidden", enabled !== "on");
    if (enabled === "on") {
      var typeRadio = document.querySelector("input[name='limit-type']:checked");
      var type = typeRadio ? typeRadio.value : "permanent";
      if (limitPermanent) limitPermanent.classList.toggle("hidden", type !== "permanent");
      if (limitTimed) limitTimed.classList.toggle("hidden", type !== "timed");
      if (limitDisconnect) limitDisconnect.classList.toggle("hidden", type !== "disconnect");
    }

    // Blocked IP list only when enabled
    var blockedIpPanel = document.getElementById("blocked-ip-panel");
    if (blockedIpPanel) {
      blockedIpPanel.classList.toggle("hidden", enabled !== "on");
    }
  }

  // Delegation for radio change (avoid lost listeners)
  var rateLimitPanel = document.getElementById("rate-limit");
  if (rateLimitPanel) {
    rateLimitPanel.addEventListener("change", function (e) {
      if (e.target.matches("input[name='limit-enabled'], input[name='limit-type']")) {
        updateLimitSection();
      }
    });
  }

  function saveLimitConfig() {
    const enabled = document.querySelector("input[name='limit-enabled']:checked").value;
    const maintype = enabled === "on" ? "1" : "0";

    if (enabled === "off") {
      fetch('/updatescanerconf', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ maintype: "0" })
      })
        .then(response => {
          if (response.ok) alert(t('msg.rate_limit_disabled'));
          else alert(t('msg.save_failed'));
        })
        .catch(error => {
          console.error('Error:', error);
          alert(t('msg.save_failed'));
        });
      return;
    }

    const childtypeRadio = document.querySelector("input[name='limit-type']:checked");
    let childtype;
    if (childtypeRadio.value === "permanent") childtype = "0";
    else if (childtypeRadio.value === "timed") childtype = "1";
    else if (childtypeRadio.value === "disconnect") childtype = "3";

    let range_t, count_t, ban_t;
    if (childtype === "0") {
      range_t = document.getElementById("limit-permanent-period").value;
      count_t = document.getElementById("limit-permanent-count").value;
      ban_t = "-1";
    } else if (childtype === "1") {
      range_t = document.getElementById("limit-timed-period").value;
      count_t = document.getElementById("limit-timed-count").value;
      ban_t = document.getElementById("limit-timed-duration").value;
    } else {
      range_t = "0";
      count_t = "0";
      ban_t = "-1";
    }

    fetch('/updatescanerconf', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        maintype: maintype,
        childtype: childtype,
        range_t: range_t,
        count_t: count_t,
        ban_t: ban_t
      })
    })
      .then(response => {
        if (response.ok) alert(t('msg.rate_limit_saved'));
        else alert(t('msg.save_failed'));
      })
      .catch(error => {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  }

  let limitConfigEventsInited = false;

  function initLimitConfigEvents() {
    updateLimitSection();

    const saveBtn = document.getElementById("limit-config-save-btn");
    if (saveBtn) {
      saveBtn.removeEventListener("click", saveLimitConfig);
      saveBtn.addEventListener("click", saveLimitConfig);
    }
  }

  // Rate limit blocked IPs

  function fetchBlockedIpList() {
    fetch('/getblockediplist')
      .then(response => response.json())
      .then(data => {
        const items = Array.isArray(data.data) ? data.data : [];
        // Compat: string to object
        const normalized = items.map(item => {
          if (typeof item === 'string') {
            return { ip: item, type: 'manual', remark: t('ratelimit.remark_manual'), value: 1, remaining: 0 };
          }
          return item;
        });
        renderBlockedIpList(normalized);
      })
      .catch(error => {
        console.error('Error fetching blocked IP list:', error);
        renderBlockedIpList([]);
      });
  }

  function renderBlockedIpList(items) {
    const tbody = document.getElementById("blocked-ip-table-body");
    if (!tbody) return;
    tbody.innerHTML = "";
    if (!items || items.length === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="empty-hint">' + t('ratelimit.no_blocked') + '</td></tr>';
      return;
    }
    items.sort((a, b) => (a.ip || "").localeCompare(b.ip || "")).forEach((item) => {
      const tr = document.createElement("tr");
      tr.innerHTML =
        '<td><input type="checkbox" class="blocked-ip-check" data-ip="' + (item.ip || "") + '"></td>' +
        '<td>' + (item.ip || "") + '</td>' +
        '<td>' + (item.remark || "") + '</td>';
      tbody.appendChild(tr);
    });
  }

  function addBlockedIps() {
    const input = document.getElementById("blocked-ip-input");
    if (!input) return;
    const raw = input.value.trim();
    if (!raw) {
      alert(t("msg.input_ip_first"));
      return;
    }
    const ips = raw.split(",").map(item => item.trim()).filter(Boolean);
    if (ips.length === 0) {
      alert(t("msg.input_ip_first"));
      return;
    }

    fetch('/updateblockediplist', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ action: "add", ips: ips })
    })
    .then(response => response.json())
    .then(data => {
      if (data.code === 1) {
        alert(data.message);
        input.value = "";
        fetchBlockedIpList();
      } else {
        alert(t('msg.add_failed', (data.message || 'Unknown error')));
      }
    })
    .catch(error => {
      console.error('Error:', error);
      alert(t('msg.add_failed_retry'));
    });
  }

  function deleteBlockedIps() {
    const checks = document.querySelectorAll(".blocked-ip-check:checked");
    if (checks.length === 0) {
      alert(t("msg.select_ips_first"));
      return;
    }
    const ips = Array.from(checks).map(cb => cb.getAttribute("data-ip")).filter(Boolean);

    fetch('/updateblockediplist', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ action: "delete", ips: ips })
    })
    .then(response => response.json())
    .then(data => {
      if (data.code === 1) {
        alert(data.message);
        fetchBlockedIpList();
      } else {
        alert(t('msg.delete_failed', (data.message || 'Unknown error')));
      }
    })
    .catch(error => {
      console.error('Error:', error);
      alert(t('msg.delete_failed_retry'));
    });
  }

  function initBlockedIpEvents() {
    const addBtn = document.getElementById("blocked-ip-add-btn");
    if (addBtn) {
      addBtn.addEventListener("click", addBlockedIps);
    }

    const deleteBtn = document.getElementById("blocked-ip-delete-btn");
    if (deleteBtn) {
      deleteBtn.addEventListener("click", deleteBlockedIps);
    }

    const input = document.getElementById("blocked-ip-input");
    if (input) {
      input.addEventListener("keydown", function (event) {
        if (event.key === "Enter" && !event.shiftKey) {
          event.preventDefault();
          addBlockedIps();
        }
      });
    }

    // Select all / none
    const selectAll = document.getElementById("blocked-ip-select-all");
    if (selectAll) {
      selectAll.addEventListener("change", function () {
        const checks = document.querySelectorAll(".blocked-ip-check");
        checks.forEach(cb => { cb.checked = selectAll.checked; });
      });
    }
  }

  initBlockedIpEvents();

  // Anti-scan blocked IPs

  function fetchCcBlockedIpList() {
    fetch('/getccblockediplist')
      .then(response => response.json())
      .then(data => {
        const items = Array.isArray(data.data) ? data.data : [];
        const normalized = items.map(item => {
          if (typeof item === 'string') {
            return { ip: item, type: 'manual', remark: t('ratelimit.remark_manual'), value: 1, remaining: 0 };
          }
          return item;
        });
        renderCcBlockedIpList(normalized);
      })
      .catch(error => {
        console.error('Error fetching CC blocked IP list:', error);
        renderCcBlockedIpList([]);
      });
  }

  function renderCcBlockedIpList(items) {
    const tbody = document.getElementById("cc-blocked-ip-table-body");
    if (!tbody) return;
    tbody.innerHTML = "";
    if (!items || items.length === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="empty-hint">' + t('ratelimit.no_blocked') + '</td></tr>';
      return;
    }
    items.sort((a, b) => (a.ip || "").localeCompare(b.ip || "")).forEach((item) => {
      const tr = document.createElement("tr");
      tr.innerHTML =
        '<td><input type="checkbox" class="cc-blocked-ip-check" data-ip="' + (item.ip || "") + '"></td>' +
        '<td>' + (item.ip || "") + '</td>' +
        '<td>' + (item.remark || "") + '</td>';
      tbody.appendChild(tr);
    });
  }

  function addCcBlockedIps() {
    const input = document.getElementById("cc-blocked-ip-input");
    if (!input) return;
    const raw = input.value.trim();
    if (!raw) {
      alert(t("msg.input_ip_first"));
      return;
    }
    const ips = raw.split(",").map(item => item.trim()).filter(Boolean);
    if (ips.length === 0) {
      alert(t("msg.input_ip_first"));
      return;
    }

    fetch('/updateccblockediplist', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ action: "add", ips: ips })
    })
    .then(response => response.json())
    .then(data => {
      if (data.code === 1) {
        alert(data.message);
        input.value = "";
        fetchCcBlockedIpList();
      } else {
        alert(t('msg.add_failed', (data.message || 'Unknown error')));
      }
    })
    .catch(error => {
      console.error('Error:', error);
      alert(t('msg.add_failed_retry'));
    });
  }

  function deleteCcBlockedIps() {
    const checks = document.querySelectorAll(".cc-blocked-ip-check:checked");
    if (checks.length === 0) {
      alert(t("msg.select_ips_first"));
      return;
    }
    const ips = Array.from(checks).map(cb => cb.getAttribute("data-ip")).filter(Boolean);

    fetch('/updateccblockediplist', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ action: "delete", ips: ips })
    })
    .then(response => response.json())
    .then(data => {
      if (data.code === 1) {
        alert(data.message);
        fetchCcBlockedIpList();
      } else {
        alert(t('msg.delete_failed', (data.message || 'Unknown error')));
      }
    })
    .catch(error => {
      console.error('Error:', error);
      alert(t('msg.delete_failed_retry'));
    });
  }

  function initCcBlockedIpEvents() {
    const addBtn = document.getElementById("cc-blocked-ip-add-btn");
    if (addBtn) {
      addBtn.addEventListener("click", addCcBlockedIps);
    }

    const deleteBtn = document.getElementById("cc-blocked-ip-delete-btn");
    if (deleteBtn) {
      deleteBtn.addEventListener("click", deleteCcBlockedIps);
    }

    const input = document.getElementById("cc-blocked-ip-input");
    if (input) {
      input.addEventListener("keydown", function (event) {
        if (event.key === "Enter" && !event.shiftKey) {
          event.preventDefault();
          addCcBlockedIps();
        }
      });
    }

    // Select all / none
    const selectAll = document.getElementById("cc-blocked-ip-select-all");
    if (selectAll) {
      selectAll.addEventListener("change", function () {
        const checks = document.querySelectorAll(".cc-blocked-ip-check");
        checks.forEach(cb => { cb.checked = selectAll.checked; });
      });
    }
  }

  initCcBlockedIpEvents();

  // System param save events

  document.querySelectorAll("[data-action='save-global-config']").forEach(function (button) {
    button.addEventListener("click", function () {
      var checked = document.querySelector("input[name='global-config']:checked");
      if (!checked) return;
      saveSystemConfig('global_config',
        { global_config: parseInt(checked.value) },
        'msg.global_config_saved');
    });
  });

  document.querySelectorAll("[data-action='save-policy-status']").forEach(function (button) {
    button.addEventListener("click", function () {
      var checked = document.querySelector("input[name='policy-status']:checked");
      if (!checked) return;
      saveSystemConfig('policystatus',
        { policystatus: parseInt(checked.value) },
        'msg.policy_saved');
    });
  });

  document.querySelectorAll("[data-action='save-full-log']").forEach(function (button) {
    button.addEventListener("click", function () {
      var checked = document.querySelector("input[name='full-log']:checked");
      if (!checked) return;
      saveSystemConfig('full_log',
        { full_log: parseInt(checked.value) },
        'msg.full_log_saved');
    });
  });

  document.querySelectorAll("[data-action='save-real-ip']").forEach(function (button) {
    button.addEventListener("click", function () {
      var input = document.getElementById('real-ip-header');
      var value = input ? input.value.trim() : '';
      saveSystemConfig('realIpHeader',
        { realIpHeader: value },
        'msg.real_ip_saved');
    });
  });

  document.querySelectorAll("[data-action='save-active-time']").forEach(function (button) {
    button.addEventListener("click", function () {
      var sel = document.getElementById('active-time-select');
      if (!sel) return;
      saveSystemConfig('active_time',
        { active_time: parseInt(sel.value) },
        'msg.active_time_saved');
    });
  });

  // Anti-scan config

  const scanSetting = document.getElementById("scan-settings");
  const scanPermanent = document.getElementById("scan-permanent");
  const scanTimed = document.getElementById("scan-timed");

  function updateScanSection() {
    var enabledRadio = document.querySelector("input[name='scan-enabled']:checked");
    if (!enabledRadio || !scanSetting) return;
    var enabled = enabledRadio.value;
    scanSetting.classList.toggle("hidden", enabled !== "on");
    if (enabled === "on") {
      var typeRadio = document.querySelector("input[name='scan-type']:checked");
      var type = typeRadio ? typeRadio.value : "permanent";
      if (scanPermanent) scanPermanent.classList.toggle("hidden", type !== "permanent");
      if (scanTimed) scanTimed.classList.toggle("hidden", type !== "timed");
    }

    // CC blocked IPs only when enabled
    var ccBlockedPanel = document.getElementById("cc-blocked-ip-panel");
    if (ccBlockedPanel) {
      ccBlockedPanel.classList.toggle("hidden", enabled !== "on");
    }
  }

  // Delegation for radio change (avoid lost listeners)
  var antiScanPanel = document.getElementById("anti-scan");
  if (antiScanPanel) {
    antiScanPanel.addEventListener("change", function (e) {
      if (e.target.matches("input[name='scan-enabled'], input[name='scan-type']")) {
        updateScanSection();
      }
    });
  }

  function fetchScanConfig() {
    fetch('/getccscanconf')
      .then(response => response.json())
      .then(data => {
        // Anti-scan toggle: cc_maintype 1=on 0=off
        const enabledRadio = document.querySelector(`input[name="scan-enabled"][value="${data.cc_maintype === 1 ? 'on' : 'off'}"]`);
        if (enabledRadio) enabledRadio.checked = true;

        // Block type: cc_childtype 0=perm 1=timed
        const typeValue = data.cc_childtype === 1 ? 'timed' : 'permanent';
        const typeRadio = document.querySelector(`input[name="scan-type"][value="${typeValue}"]`);
        if (typeRadio) typeRadio.checked = true;

        // Detection period
        document.getElementById('scan-permanent-period').value = data.cc_limit_time || '';
        document.getElementById('scan-timed-period').value = data.cc_limit_time || '';

        // Count
        document.getElementById('scan-permanent-count').value = data.cc_limit_number || '';
        document.getElementById('scan-timed-count').value = data.cc_limit_number || '';

        // Block duration
        document.getElementById('scan-timed-duration').value = data.cc_ban_t || '';

        // Status codes from same endpoint
        const raw = data.cc_alerm_code || "";
        if (raw.trim()) {
          currentScanCodes = raw.trim().split(/\s+/);
        } else {
          currentScanCodes = [];
        }
        scanCodeSelected = new Set();
        renderScanCodeTags();

        updateScanSection();
      })
      .catch(error => {
        console.error('Error fetching scan config:', error);
      });
  }

  function saveScanConfig() {
    const enabled = document.querySelector("input[name='scan-enabled']:checked").value;
    const data = {
      cc_maintype: enabled === "on" ? 1 : 0
    };

    if (enabled === "on") {
      const childtypeRadio = document.querySelector("input[name='scan-type']:checked");
      data.cc_childtype = childtypeRadio.value === "timed" ? 1 : 0;

      if (data.cc_childtype === 0) {
        // Permanent block
        data.cc_limit_time = document.getElementById("scan-permanent-period").value;
        data.cc_limit_number = document.getElementById("scan-permanent-count").value;
        data.cc_ban_t = "-1";
      } else {
        // Timed block
        data.cc_limit_time = document.getElementById("scan-timed-period").value;
        data.cc_limit_number = document.getElementById("scan-timed-count").value;
        data.cc_ban_t = document.getElementById("scan-timed-duration").value;
      }
    }

    fetch('/updateglobalconfig', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data)
    })
      .then(response => {
        if (response.ok) {
          alert(t('msg.scan_saved'));
        } else {
          alert(t('msg.save_failed'));
        }
      })
      .catch(error => {
        console.error('Error:', error);
        alert(t('msg.save_failed'));
      });
  }

  let scanConfigEventsInited = false;

  function initScanConfigEvents() {
    // Refresh display (radio events via delegation)
    updateScanSection();

    const saveBtn = document.getElementById("scan-config-save-btn");
    if (saveBtn) {
      saveBtn.removeEventListener("click", saveScanConfig);
      saveBtn.addEventListener("click", saveScanConfig);
    }
  }

  // Logout
  (function initLogout() {
    var logoutBtn = document.getElementById("sidebar-logout-btn");
    var logoutModal = document.getElementById("logout-modal");
    var logoutCancel = document.getElementById("logout-cancel");
    var logoutConfirm = document.getElementById("logout-confirm");
    var backdrop = logoutModal.querySelector(".modal-backdrop");

    if (!logoutBtn || !logoutModal) return;

    function openModal() {
      logoutModal.classList.remove("hidden");
    }

    function closeModal() {
      logoutModal.classList.add("hidden");
    }

    function performLogout() {
      closeModal();

      // Call logout API, clear server token
      fetch('/auth/logout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      }).then(function() {
        try { sessionStorage.clear(); } catch (e) {}
        try { localStorage.clear(); } catch (e) {}
        window.location.href = '/login.html';
      }).catch(function() {
        // Clear local state & redirect on error
        try { sessionStorage.clear(); } catch (e) {}
        try { localStorage.clear(); } catch (e) {}
        window.location.href = '/login.html';
      });
    }

    logoutBtn.addEventListener("click", openModal);
    logoutCancel.addEventListener("click", closeModal);
    logoutConfirm.addEventListener("click", performLogout);
    backdrop.addEventListener("click", closeModal);

    // ESC close modal
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && !logoutModal.classList.contains("hidden")) {
        closeModal();
      }
    });
  })();

  // Restore last page (must be at end to avoid TDZ)
  var initialPage;
  try { initialPage = sessionStorage.getItem("activePage"); } catch (e) {}
  initialPage = initialPage || "dashboard";
  showPage(initialPage);
});
