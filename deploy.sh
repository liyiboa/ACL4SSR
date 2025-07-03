#!/bin/bash

# ====== 配置运行目录 ======
WORKDIR="\$HOME/playfast-renew"
SCRIPT_NAME="renew.sh"
COOKIE_FILE="\$WORKDIR/.playfast_cookie"
LOG_FILE="\$WORKDIR/renew.log"
CRON_CMD="bash \$WORKDIR/\$SCRIPT_NAME >> \$LOG_FILE 2>&1"

mkdir -p "\$WORKDIR"

# ====== 写入主脚本 ======
cat > "\$WORKDIR/\$SCRIPT_NAME" <<'EOF'
#!/bin/bash

EMAIL="3107981740@qq.com"
PASSWORD="liyibo123"
SERVER_ID="78d8a8be-4036-4ba7-a39d-2ddd5b120abb"
BARK_KEY="wCtZY9JuC7xaMLsjg4GJRo"
LOGIN_URL="https://playfast.org/login"
COOKIE_FILE="\$(dirname "\$0")/.playfast_cookie"
UA="Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1"

load_cookie() {
  TOKEN=\$(grep 'token' "\$COOKIE_FILE" 2>/dev/null | awk '{print \$NF}')
  EMAIL_COOKIE=\$(grep 'email' "\$COOKIE_FILE" 2>/dev/null | awk '{print \$NF}')
  CF_COOKIE=\$(grep 'cf_clearance' "\$COOKIE_FILE" 2>/dev/null | awk '{print \$NF}')
}

login_and_save_cookie() {
  echo "🔐 执行登录..."

  curl -s -i -c "\$COOKIE_FILE" -X POST "\$LOGIN_URL" \\
    -H "Content-Type: application/x-www-form-urlencoded" \\
    -H "Origin: https://playfast.org" \\
    -H "Referer: https://playfast.org/login" \\
    -H "User-Agent: \$UA" \\
    --data "email=\$EMAIL&password=\$PASSWORD&remember=on" > "\$(dirname "\$0")/login_response.log"

  load_cookie

  if [[ -z "\$TOKEN" ]]; then
    echo "❌ 登录失败，未获取 token"
    cat "\$(dirname "\$0")/login_response.log"
    rm -f "\$COOKIE_FILE"
    exit 1
  fi

  echo "✅ 登录成功，token 获取成功"
}

get_reqid() {
  echo "📺 获取 reqID..."
  JS_URL="https://playfast.org/ad-units.js?req_id="
  REQ_ID=\$(curl -s "\$JS_URL" \\
    -H "User-Agent: \$UA" \\
    -H "Referer: https://playfast.org/dashboard/servers/\$SERVER_ID" \\
    -H "Accept: */*" --compressed \\
    | grep -oE "reqID='[a-z0-9\\-]+'" | cut -d"'" -f2)

  if [[ -z "\$REQ_ID" ]]; then
    echo "❌ 获取 reqID 失败"
    exit 1
  fi

  echo "✅ 获取到 reqID: \$REQ_ID"
}

renew_and_push() {
  echo "🚀 尝试续期..."
  RENEW_URL="https://playfast.org/api/servers/\$SERVER_ID/renew?req_id=\$REQ_ID"

  RESPONSE=\$(curl -i -s -X POST "\$RENEW_URL" \\
    -H "Origin: https://playfast.org" \\
    -H "Referer: https://playfast.org/dashboard/servers/\$SERVER_ID" \\
    -H "User-Agent: \$UA" \\
    -H "Accept: */*" \\
    -H "Cookie: prefetchAd_9480514=true; token=\$TOKEN; email=\$EMAIL_COOKIE; cf_clearance=\$CF_COOKIE" \\
    --compressed --data "")

  if echo "\$RESPONSE" | grep -q "请先登录"; then
    echo "⚠️ Cookie 失效，尝试重新登录"
    login_and_save_cookie
    renew_and_push
    return
  fi

  RESP_DATE=\$(echo "\$RESPONSE" | grep -i '^Date:' | sed 's/Date: //I')
  MSG=\$(echo "\$RESPONSE" | grep -o '"msg":"[^"]*"' | cut -d':' -f2 | tr -d '"')

  echo "📩 消息: \$MSG"
  echo "⏰ 响应时间: \$RESP_DATE"

  if echo "\$RESPONSE" | grep -q "启动成功"; then
    BARK_MSG="✅ Playfast 续费成功"
  else
    BARK_MSG="❌ Playfast 续费失败"
  fi

  TITLE="Playfast 续费结果"
  TITLE_ENC=\$(echo "\$TITLE" | sed 's/ /%20/g')
  MSG_ENC=\$(echo "\$BARK_MSG" | sed 's/ /%20/g')
  curl -s "https://api.day.app/\$BARK_KEY/\$TITLE_ENC/\$MSG_ENC" > /dev/null

  echo "\$BARK_MSG（已通过 Bark 推送）"
}

load_cookie
get_reqid
renew_and_push
EOF

chmod +x "\$WORKDIR/\$SCRIPT_NAME"

# ====== 添加定时任务（每天 6 点） ======
( crontab -l 2>/dev/null | grep -v "\$SCRIPT_NAME" ; echo "0 6 * * * bash \$WORKDIR/\$SCRIPT_NAME >> \$LOG_FILE 2>&1" ) | crontab -

# ====== 输出结果 ======
echo "✅ 脚本已部署到: \$WORKDIR/\$SCRIPT_NAME"
echo "✅ 日志将输出到: \$LOG_FILE"
echo "✅ 已添加定时任务: 每天 6 点自动续费"

crontab -l | grep "\$SCRIPT_NAME"
