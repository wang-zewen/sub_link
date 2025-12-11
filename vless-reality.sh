#!/bin/bash
set -e

# ==================== 配置 ====================
PORT=${PORT:-${SERVER_PORT:-20041}}
UUID=${VLESS_UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)}
V=1.8.24

# Reality 配置
DEST=${REALITY_DEST:-"www.microsoft.com:443"}
SERVER_NAMES=${REALITY_SERVER_NAMES:-"www.microsoft.com"}

echo "🚀 VLESS+Reality Server"
echo "📌 Port: $PORT"

# ==================== 获取 IP ====================
IP=$(curl -s --connect-timeout 3 https://api64.ipify.org||curl -s --connect-timeout 3 https://ifconfig.me||echo "UNKNOWN")
echo "✅ Server IP: $IP"

# ==================== 下载 Xray ====================
[ ! -f xray ]&&(echo "📥 Downloading Xray...";curl -sLo x.zip https://github.com/XTLS/Xray-core/releases/download/v${V}/Xray-linux-64.zip;unzip -qo x.zip xray;chmod +x xray;rm x.zip;echo "✅ Xray installed")

# ==================== 生成 Reality 密钥对 ====================
echo "🔐 Generating Reality keys..."
KEYS=$(./xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public key:" | awk '{print $3}')

# 生成 ShortId（8字节十六进制）
SHORT_ID=$(openssl rand -hex 8 2>/dev/null || xxd -l 8 -p /dev/urandom | head -1)

echo "✅ Keys generated"

# ==================== 生成 Xray 配置 ====================
cat > c.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${DEST}",
          "xver": 0,
          "serverNames": [
            "${SERVER_NAMES}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

# ==================== 生成 VLESS 链接 ====================
# VLESS 格式: vless://UUID@IP:PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=SNI&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp&headerType=none#NAME
VLESS_LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SERVER_NAMES}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#VLESS-Reality"

echo "$VLESS_LINK" > link.txt

echo ""
echo "=========================================="
echo "🎉 VLESS+Reality Server Ready!"
echo "=========================================="
echo "📍 Server: $IP:$PORT"
echo "🔑 UUID: $UUID"
echo "🔒 Public Key: $PUBLIC_KEY"
echo "🆔 Short ID: $SHORT_ID"
echo "🌐 SNI: $SERVER_NAMES"
echo "🎯 Dest: $DEST"
echo ""
echo "🔗 VLESS Link:"
echo "$VLESS_LINK"
echo ""
echo "💾 Link saved to: link.txt"
echo "=========================================="
echo ""

echo "🚀 Starting Xray..."
while :;do ./xray run -c c.json 2>&1 ||sleep 3;done
