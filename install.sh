
pkg update
opkg install modemmanager curl jq git git-http ca-bundle

cp smsbot.sh /root/smsbot.sh
chmod +x /root/smsbot.sh

cp rc.local /etc/rc.local
chmod +x /etc/rc.local

rm -f /tmp/smsbot.lock
sh /root/smsbot.sh &
