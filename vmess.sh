#!/bin/bash
set -e

# 配置
XRAY_VERSION="1.8.24"
PORT="${SERVER_PORT:-20041}"
UUID="${VMESS_UUID:-$(cat /proc/sys/kernel/random/uuid)}"

echo "🚀 VMess Server Setup"
echo "Port: $PORT"
echo "UUID: $UUID"

# 下载 Xray
if [ ! -f "./xray" ]; then
    echo "📥 Downloading Xray..."
    curl -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
    unzip -o xray.zip xray
    chmod +x xray
    rm xray.zip
    echo "✅ Xray downloaded"
fi

# 生成配置
cat > config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# 生成 VMess 链接
VMESS_JSON=$(cat <<EOFVM
{
  "v": "2",
  "ps": "VMess-WispByte",
  "add": "${SERVER_IP:-your-server-ip}",
  "port": "${PORT}",
  "id": "${UUID}",
  "aid": "0",
  "net": "tcp",
  "type": "none",
  "tls": ""
}
EOFVM
)

VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"

echo ""
echo "=========================================="
echo "🎉 VMess Server Ready!"
echo "=========================================="
echo "Server: ${SERVER_IP:-your-server-ip}"
echo "Port: ${PORT}"
echo "UUID: ${UUID}"
echo ""
echo "🔗 VMess Link:"
echo "$VMESS_LINK"
echo "=========================================="
echo ""

# 保存链接
echo "$VMESS_LINK" > vmess_link.txt

# 启动 Xray（带重启）
echo "🚀 Starting Xray..."
while true; do
    ./xray run -c config.json || true
    echo "⚠️ Xray crashed, restarting in 5s..."
    sleep 5
done
