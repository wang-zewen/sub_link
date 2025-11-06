#!/bin/bash
set -e

# ==================== 配置 ====================
PORT=${PORT:-${SERVER_PORT:-20041}}
UUID=${VMESS_UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)}
V=1.8.24

echo "🚀 VMess Server"
echo "📌 Port: $PORT"

# ==================== 获取 IP ====================
IP=$(curl -s --connect-timeout 3 https://api64.ipify.org||curl -s --connect-timeout 3 https://ifconfig.me||echo "UNKNOWN")
echo "✅ Server IP: $IP"

# ==================== 下载 Xray ====================
[ ! -f xray ]&&(echo "📥 Downloading Xray...";curl -sLo x.zip https://github.com/XTLS/Xray-core/releases/download/v${V}/Xray-linux-64.zip;unzip -qo x.zip xray;chmod +x xray;rm x.zip;echo "✅ Xray installed")

# ==================== 生成 Xray 配置 ====================
cat > c.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "${UUID}", "alterId": 0}]
      },
      "streamSettings": {
        "network": "tcp",
        "tcpSettings": {
          "acceptProxyProtocol": false,
          "header": {
            "type": "http",
            "response": {
              "version": "1.1",
              "status": "200",
              "reason": "OK",
              "headers": {
                "Content-Type": ["text/html; charset=utf-8"],
                "Transfer-Encoding": ["chunked"],
                "Connection": ["keep-alive"],
                "Pragma": "no-cache"
              }
            }
          }
        }
      },
      "tag": "vmess"
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# ==================== 生成 VMess 链接 ====================
L="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"VMess-Server\",\"add\":\"$IP\",\"port\":\"$PORT\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"tls\":\"\"}"|base64 -w 0)"
echo "$L" > link.txt

echo ""
echo "=========================================="
echo "🎉 VMess Server Ready!"
echo "=========================================="
echo "📍 Server: $IP:$PORT"
echo "🔑 UUID: $UUID"
echo ""
echo "🔗 VMess Link:"
echo "$L"
echo ""
echo "💾 Link saved to: link.txt"
echo "=========================================="
echo ""

echo "🚀 Starting Xray..."
while :;do ./xray run -c c.json 2>/dev/null||sleep 3;done
