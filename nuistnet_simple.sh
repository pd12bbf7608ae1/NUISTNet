#!/bin/bash
# 该脚本为精简版 仅保留登录功能 直接运行即可
# debug=1

# 用户名 密码
username='username'
password='password'

# 网络供应商
isp="校园网"
# isp="中国移动"
# isp="中国电信"
# isp="中国联通"

userAgent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.105 Safari/537.36"
# loginServer='10.255.255.34'
loginServer='10.255.255.46' # 修改后
getIPUrl="http://${loginServer}/api/v1/ip"
loginUrl="http://${loginServer}/api/v1/login"
infoUrl="http://${loginServer}/api/v1/login"
logoutUrl="http://${loginServer}/api/v1/login"

fontRed='\033[31m'
fontGreen='\033[32m'
fontBlue='\033[36m'
fontNormal='\033[0m'

function echoRed() {
    echo -e "${fontRed}${*}${fontNormal}"
}
function echoBlue() {
    echo -e "${fontBlue}${*}${fontNormal}"
}
function echoGreen() {
    echo -e "${fontGreen}${*}${fontNormal}"
}
function debug() {
    if [ "$debug" == "1" ]; then
        echo "$*" 
    fi
}

# 获取IP
# GET http://10.255.255.46/api/v1/ip
# Response {"code":200,"data":"10.0.0.1"}

function GetIP() { # 从学校api获取本机IP地址 # 返回0 成功 返回1失败
    local curlInfo curlCode
    echoBlue '获取本地IP...' 1>&2
    debug "GET ${getIPUrl}" 1>&2
    curlInfo=$(curl --connect-timeout 5 -X "GET" -w "\nCode:%{response_code}" -H "User-Agent: ${userAgent}" "${getIPUrl}")
    curlCode="$?"
    debug "${curlInfo}" 1>&2
    if [[ "$curlCode" -ne 0 ]]; then
        echoRed "curl 错误 Code:${curlCode}" 1>&2
        return 1
    else
        local responseCode=$(echo "${curlInfo}" | sed -n '$p' | sed -e "s/.*Code://g")
        if [[ "$responseCode" != "200" ]]; then
            echoRed "Http响应码错误 Code:${responseCode}" 1>&2
            return 1
        else
            curlInfo=$(echo "${curlInfo}" | sed -e 's/Code:...//g' | tr -d '\r' | sed -e 's/^[[:blank:]]*//g' -e 's/[[:blank:]]*$//g' | tr -d '\n')
            local IP=$(echo "${curlInfo}"  | sed -n "s/.*\"data\":[[:blank:]]*\"\([0-9.]\+\)\".*/\1/p")
            local apiCode=$(echo "${curlInfo}" | sed -n "s/.*\"code\":[[:blank:]]*\([0-9]\+\).*/\1/p")
            if [[ "${apiCode}" != "200" ]]; then
                echoRed "api响应码错误 Code:${apiCode}" 1>&2
                return 1
            elif [[ -z "${IP}" ]]; then
                echoRed "api返回IP为空" 1>&2
                return 1
            fi
            echo "$IP"
            echoGreen "IP获取成功" 1>&2
            echoGreen "地址: ${IP}" 1>&2
            return 0
        fi
        
    fi
}

function GetChannelIdOffline() { # 硬编码 Channel id
    echoBlue "使用硬编码ID" 1>&2
    case "${isp}" in
        "校园网")
        echo '1'
        return 0;;
        "中国移动")
        echo '2'
        return 0;;
        "中国电信")
        echo '3'
        return 0;;
        "中国联通")
        echo '4'
        return 0;;
        *)
        return 1;;
    esac
}

# 登录
# POST http://10.255.255.46/api/v1/login
# Request {"username":"123456","password":"123456","ifautologin":"0","channel":"1","pagesign":"secondauth","usripadd":"10.0.0.1"}
# Response 
# {
#     "code": 201,
#     "message": "ok",
#     "data":
#         {
#             "text": "该用户没有开通校园网服务，请开通后再试。 The user has not opened the campus network service.",
#             "url": null 
#         }
# }


function Login() { # 进行登录操作 返回0 成功 返回1失败
    local curlInfo curlCode
    if [[ -z "${IP}" ]]; then
        IP=$(GetIP)
        if [[ "$?" -ne "0" ]]; then
            echoRed 'IP获取失败' 1>&2
            exit 1
        fi
    fi
    echoBlue "尝试登录..." 1>&2
    local postBody="{\"username\":\"${username}\",\"password\":\"${password}\",\"channel\":\"${channelId}\",\"ifautologin\":\"0\",\"pagesign\":\"secondauth\",\"usripadd\":\"${IP}\"}"
    debug "POST ${loginUrl}" 1>&2
    debug "Body ${postBody}" 1>&2
    curlInfo=$(curl --connect-timeout 5 -X "POST" -w "\nCode:%{response_code}" -H "User-Agent: ${userAgent}" -d "${postBody}" "${loginUrl}")
    curlCode="$?"
    debug "${curlInfo}" 1>&2
    if [[ "$curlCode" -ne 0 ]]; then
        echoRed "curl 错误 Code:${curlCode}" 1>&2
        return 1
    else
        local responseCode=$(echo "${curlInfo}" | sed -n '$p' | sed -e "s/.*Code://g")
        if [[ "$responseCode" != "200" ]]; then
            echoRed "Http响应码错误 Code:${responseCode}" 1>&2
            return 1
        else
            echoGreen "登录信息发送成功" 1>&2
        fi
    fi
}

function CheckLoginServer() { # 测试登录服务器是否在线 0在线
    curl --connect-timeout 5 -H "User-Agent: ${userAgent}" "http://${loginServer}" > /dev/null 2>/dev/null
    return $?
}

function CheckAliDns() { # 测试网络通断 0在线
    ping -c 2 223.5.5.5 > /dev/null 2>/dev/null
    return $?
}

function CheckAndLogin() { # 进行网络状态检查，然后登录
    echoBlue "测试网络通断..." 1>&2
    CheckAliDns
    if [[ "$?" -eq "0" ]]; then
        echoBlue "已经联网，退出" 1>&2
        exit 0
    fi

    echoBlue "网络断开，尝试连接登录服务器..." 1>&2
    CheckLoginServer
    if [[ "$?" -ne "0" ]]; then
        echoBlue "登录服务器无法连接，退出..." 1>&2
        exit 0
    fi

    channelId=$(GetChannelIdOffline)
    if [[ -z "${channelId}" ]]; then # 未得到Channel ID
        echoRed "channelId缺失，请检测isp设置..." 1>&2
        exit 1
    fi
    Login
    exit "$?"
}

CheckAndLogin
