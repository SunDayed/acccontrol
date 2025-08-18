//初始化区域封禁内容
querryofallmsg(updatelocal_of_response);
//初始化黑白名单ip列表
update_ip_address(updateiplist_of_response);
//初始化限流策略
querryofscanermsg()


function querryofscanermsg() {
    var url = "/getscanerconf";
    var type = "json";
    $.ajax({
        url: url,
        crossDomain: true,
        xhrFields: {
            withCredentials: true,
        },
        dataType: type,
        success: function (data) {
            updatescaner_of_response(data);
        },
        error: function (jqXHR, textstatus, errorthrown) {
            if (window.console) console.log("intreface err");
        }
    });
}
function updatescaner_of_response(data) {
    if (!data) {
        console.error("No data received!");
        return;
    }
    console.log(data)
    const mainOptions = document.querySelectorAll('input[name="mainOption"]');
    const subOptions = document.querySelectorAll('input[name="subOption"]');
    const rangeTInput = document.querySelector('input[name="range_t"]');
    const countTInput = document.querySelector('input[name="count_t"]');
    const banTInput = document.querySelector('input[name="ban_t"]');

    const rangeT1Input = document.querySelector('input[name="range_t1"]');
    const countT1Input = document.querySelector('input[name="count_t1"]');

    //main选项
    mainOptions.forEach(option => {
        if (option.value == data.maintype) {
            option.checked = true;
        }
    });

    if (data.maintype == '1') {
        //限流开启
        document.getElementById('subRadioGroup').classList.remove('hidden');
        if (data.childtype == '0') {
            //永久限制
            document.getElementById('PolicyGroup1').classList.remove('hidden');
            subOptions.forEach(option => {
                if (option.value == data.childtype) {
                    option.checked = true;
                }
            });
            if (rangeT1Input && countT1Input) {
                rangeT1Input.value = data.limit_time;
                countT1Input.value = data.limit_number;
            }
        } else {
            //指定时间
            document.getElementById('PolicyGroup').classList.remove('hidden');
            subOptions.forEach(option => {
                if (option.value == data.childtype) {
                    option.checked = true;
                }
            });
            if (rangeTInput && countTInput) {
                rangeTInput.value = data.limit_time;
                countTInput.value = data.limit_number;
                banTInput.value = data.ban_t;
            }
        }
    }

}

//防扫描页面展示
const mainOptions = document.querySelectorAll('input[name="mainOption"]');
const subRadioGroup = document.getElementById('subRadioGroup');
const subOptions = document.querySelectorAll('input[name="subOption"]');
const PolicyGroup = document.getElementById('PolicyGroup');
const PolicyGroup1 = document.getElementById('PolicyGroup1');

mainOptions.forEach(radio => {
    radio.addEventListener('change', function () {
        if (this.value === '1') {
            subRadioGroup.classList.remove('hidden');
            PolicyGroup1.classList.remove('hidden');
            PolicyGroup.classList.add('hidden');
            const range_t = PolicyGroup1.querySelector('input[name="range_t1"]');
            const count_t = PolicyGroup1.querySelector('input[name="count_t1"]');
            if (range_t) range_t.value = '60';
            if (count_t) count_t.value = '120';
            document.querySelectorAll('input[name="ban_t"]').forEach(t => t.value = '');
        } else {
            subRadioGroup.classList.add('hidden');
            PolicyGroup.classList.add('hidden');
            PolicyGroup1.classList.add('hidden');
        }
    });
});

subOptions.forEach(sub => {

    sub.addEventListener('change', function () {
        if (this.value === '1') {
            PolicyGroup.classList.remove('hidden');
            PolicyGroup1.classList.add('hidden');
            const range_t = PolicyGroup.querySelector('input[name="range_t"]');
            const count_t = PolicyGroup.querySelector('input[name="count_t"]');
            const ban_t = PolicyGroup.querySelector('input[name="ban_t"]');
            if (range_t) range_t.value = '60';
            if (count_t) count_t.value = '120';
            if (ban_t) ban_t.value = '3600';
        } else if (this.value === '0') {
            PolicyGroup1.classList.remove('hidden');
            PolicyGroup.classList.add('hidden');
            const range_t = PolicyGroup1.querySelector('input[name="range_t1"]');
            const count_t = PolicyGroup1.querySelector('input[name="count_t1"]');

            if (range_t) range_t.value = '60';
            if (count_t) count_t.value = '120';
            document.querySelectorAll('input[name="ban_t"]').forEach(t => t.value = '');
        } else {
            PolicyGroup.classList.add('hidden');
            PolicyGroup1.classList.remove('hidden');
            //document.querySelectorAll('input[name="range_t"],input[name="count_t"], input[name="ban_t"]').forEach(t => t.value = '');
        }
    });

});
function updatescanerbtn() {
    const mainSelected = document.querySelector('input[name="mainOption"]:checked');
    const subSelected = document.querySelector('input[name="subOption"]:checked');
    if (subSelected.value == '1') {
        //指定时间
        const range_t = document.querySelector('input[name="range_t"]').value;
        const count_t = document.querySelector('input[name="count_t"]').value;
        const ban_t = document.querySelector('input[name="ban_t"]').value;

        const result = {
            maintype: mainSelected.value,
            childtype: subSelected.value,
            range_t: range_t ? range_t : "-1",
            count_t: count_t ? count_t : "-1",
            ban_t: ban_t ? ban_t : "-1",
        };
        sendPostRequest("/updatescanerconf", result)
    }
    if (subSelected.value == '0') {
        const range_t = document.querySelector('input[name="range_t1"]').value;
        const count_t = document.querySelector('input[name="count_t1"]').value;
        const ban_t = '';
        const result = {
            maintype: mainSelected.value,
            childtype: subSelected.value,
            range_t: range_t ? range_t : "-1",
            count_t: count_t ? count_t : "-1",
            ban_t: ban_t ? ban_t : "-1",
        };
        sendPostRequest("/updatescanerconf", result)
    }
}

//区域封禁右移
function moveToRight(fromSelectId, toSelectId) {
    const fromSelect = document.getElementById(fromSelectId);
    const toSelect = document.getElementById(toSelectId);
    for (let i = fromSelect.options.length - 1; i >= 0; i--) {
        if (fromSelect.options[i].selected) {
            toSelect.appendChild(fromSelect.options[i]);
        }
    }
}
//区域封禁左移
function moveToLeft(fromSelectId, toSelectId) {
    const fromSelect = document.getElementById(fromSelectId);
    const toSelect = document.getElementById(toSelectId);
    for (let i = fromSelect.options.length - 1; i >= 0; i--) {
        if (fromSelect.options[i].selected) {
            toSelect.appendChild(fromSelect.options[i]);
        }
    }
}


function querryofallmsg(updatelocal_of_response) {
    var url = "/getaccesscontrol";
    var type = "json";
    $.ajax({
        url: url,
        crossDomain: true,
        xhrFields: {
            withCredentials: true,
        },
        dataType: type,
        success: function (data) {
            updatelocal_of_response(data);
        },
        error: function (jqXHR, textstatus, errorthrown) {
            if (window.console) console.log("intreface err");
        }
    });
}
function updatelocal_of_response(data) {
    if (!data) {
        console.error("No data received!");
        return;
    }
    //清空、更新select
    const updateSelect = (selectId, items) => {
        const select = document.getElementById(selectId);
        if (!select) {
            console.error(`Element with ID "${selectId}" not found!`);
            return;
        }
        if (items.length == undefined) { return; }
        select.innerHTML = "";
        items.forEach(item => {
            if (item != null && item !== undefined) {
                select.appendChild(new Option(String(item), String(item)));
            }
        });
    };
    //更新
    updateSelect("disallowed_state", data.state?.disallow);
    updateSelect("allowed_state", data.state?.allow);
    updateSelect("disallowed_geo", data.geo?.disallow);
    updateSelect("allowed_geo", data.geo?.allow);
    updateSelect("disallowed_cont", data.continent?.disallow);
    updateSelect("allowed_cont", data.continent?.allow);

}
function update_ip_address(updateiplist_of_response) {
    var url = "/getiplist";
    var type = "json";
    $.ajax({
        url: url,
        crossDomain: true,
        xhrFields: {
            withCredentials: true,
        },
        dataType: type,
        success: function (data) {
            updateiplist_of_response(data);
        },
        error: function (jqXHR, textstatus, errorthrown) {
            if (window.console) console.log("intreface err");
        }
    });
}
function updateiplist_of_response(data) {
    if (!data) {
        console.error("No data received!");
        return;
    }
    //清空、更新select
    const updateSelectipaddr = (selectId, items) => {
        const select = document.getElementById(selectId);
        if (!select) {
            console.error(`Element with ID "${selectId}" not found!`);
            return;
        }
        if (items.length == undefined) { return; }
        select.innerHTML = "";
        items.forEach(item => {
            if (item != null && item !== undefined) {
                select.appendChild(new Option(String(item), String(item)));
            }
        });
    };
    //更新
    updateSelectipaddr("white_ip_list", data.whitelist_ipaddr);
    updateSelectipaddr("black_ip_list", data.blacklist_ipaddr);
}




//下发更新内容
//更新区域封禁信息
function getlocaldata(name, disallowid, allowid) {
    console.log(name)
    const disallow = document.getElementById(disallowid);
    const allow = document.getElementById(allowid);

    const disallowvalues = Array.from(disallow.options).map(option => option.value);
    const allowvalues = Array.from(allow.options).map(option => option.value);
    const jsonData = {
        [name]: {
            disallow: disallowvalues,
            allow: allowvalues
        }
    };
    sendPostRequest("/updateaccesscontrol", jsonData);
}
//保存按钮
function update_ip_list(name, ip_select_id) {
    console.log(name)
    const ipselectid = document.getElementById(ip_select_id);


    const ipselects = Array.from(ipselectid.options).map(option => option.value);
    const jsonData = {
        [name]: ipselects
    };
    sendPostRequest("/updateiplist", jsonData);
}

//添加按钮
function addiplist(from_id, to_id) {
    const fromSelect = document.getElementById(from_id);
    const content = fromSelect.value;
    if (content == "") {
        alert("空值不能添加")
        return;
    }
    const toSelect = document.getElementById(to_id);

    const items = content.split(',');
    for (let i = 0; i < items.length; i++) {

        const option = document.createElement("option");
        option.textContent = items[i].trim();
        toSelect.appendChild(option);
    }
    fromSelect.value = "";
}

//删除按钮
function deleiplist(name, to_dele_id) {
    console.log(name)
    const ipdeleteid = document.getElementById(to_dele_id);
    const ipdeletes = Array.from(ipdeleteid.selectedOptions).map(option => option.value);
    const jsonData = {
        [name]: ipdeletes
    };
    sendPostRequest("/ipdel", jsonData);
    for (let i = ipdeleteid.selectedOptions.length - 1; i >= 0; i--) {
        ipdeleteid.remove(ipdeleteid.selectedOptions[i].index);
    }

}

//发送post请求
function sendPostRequest(url, data) {
    fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data)
    })
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            return response.json();
        })
        .then(data => {
            console.log('请求成功:', data);
            alert("更新成功")
        })
        .catch(error => {
            console.error('请求失败:', error);
        });
}