#!/bin/sh

LOCKFILE="/tmp/smsbot.lock"

if [ -f "$LOCKFILE" ]; then
    echo "SMS bot already running"
    exit 1
fi

touch "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

TOKEN="8719507673:AAEAZVSpnHfDu3zX8k4P8h2HxLzp5vYVAEk"
CHAT_ID="1137750839"
MODEM=0

LAST_UPDATE=0

# =========================
# MENU BOT TELEGRAM
# =========================

curl -s -X POST "https://api.telegram.org/bot$TOKEN/setMyCommands" \
-d 'commands=[
{"command":"sms","description":"Kirim SMS"},
{"command":"status","description":"Cek modem"},
{"command":"help","description":"Bantuan"}
]' >/dev/null

while true
do

# =========================
# NOTIF SMS MASUK
# =========================

SMS=$(mmcli -m $MODEM --messaging-list-sms 2>/dev/null | grep -o '/SMS/[0-9]*' | tail -n1)

if [ -n "$SMS" ]; then

SMS_ID=${SMS##*/}

TEXT=$(mmcli -s $SMS_ID 2>/dev/null)

NUMBER=$(echo "$TEXT" | grep "number:" | cut -d: -f2-)
CONTENT=$(echo "$TEXT" | grep "text:" | cut -d: -f2-)

MESSAGE="📩 SMS Baru
👤 Pengirim:$NUMBER
💬 Isi:$CONTENT"

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="$MESSAGE" >/dev/null

mmcli -m $MODEM --messaging-delete-sms=$SMS_ID >/dev/null 2>&1

fi

# =========================
# KIRIM SMS DARI TELEGRAM
# =========================

UPDATES=$(curl -s "https://api.telegram.org/bot$TOKEN/getUpdates?offset=$((LAST_UPDATE + 1))")

UPDATE_ID=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | tail -n1 | cut -d: -f2)

TEXT_CMD=$(echo "$UPDATES" | grep -o '"text":"[^"]*"' | tail -n1 | cut -d: -f2- | sed 's/^"//' | sed 's/"$//')

if [ -n "$UPDATE_ID" ] && [ "$UPDATE_ID" != "$LAST_UPDATE" ]; then

LAST_UPDATE=$UPDATE_ID

CMD=$(echo "$TEXT_CMD" | cut -d' ' -f1)

# =========================
# /sms
# =========================

if [ "$CMD" = "/sms" ]; then

NUMBER=$(echo "$TEXT_CMD" | cut -d' ' -f2)
MESSAGE_SMS=$(echo "$TEXT_CMD" | cut -d' ' -f3-)

CREATE=$(mmcli -m $MODEM --messaging-create-sms="text='$MESSAGE_SMS',number='$NUMBER'" 2>/dev/null)

SMS_PATH=$(echo "$CREATE" | grep -o '/org/freedesktop/ModemManager1/SMS/[0-9]*')

if [ -n "$SMS_PATH" ]; then

SMS_SEND_ID=${SMS_PATH##*/}

mmcli -s $SMS_SEND_ID --send >/dev/null 2>&1

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="✅ SMS berhasil dikirim ke $NUMBER" >/dev/null

else

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="❌ Gagal kirim SMS" >/dev/null

fi
fi

# =========================
# /status
# =========================

 if [ "$CMD" = "/status" ]; then

STATUS=$(mmcli -m $MODEM | grep "state:" | sed 's/\x1b\[[0-9;]*m//g' | awk -F': ' '{print $2}')

SIGNAL=$(mmcli -m $MODEM --signal-get 2>/dev/null | grep "rsrp" | awk -F': ' '{print $2}')

OPERATOR=$(mmcli -m $MODEM | grep "operator name:" | cut -d: -f2-)

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="📡 Modem Status

📶 state: $STATUS
📳 Signal: $SIGNAL
🌐 Operator:$OPERATOR" >/dev/null

fi

# =========================
# /help
# =========================

if [ "$CMD" = "/help" ]; then

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="📘 Format:

/sms nomor pesan
/status
/help" >/dev/null

fi

fi

sleep 10
done