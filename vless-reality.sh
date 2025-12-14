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

# ==================== 上传节点信息 ====================
upload_node_info() {
    # 默认API地址
    DEFAULT_API="http://103.69.129.79:8081/api/v1/groups/2/nodes"

    # 检查环境变量
    if [ -n "$SKIP_NODE_UPLOAD" ] && [ "$SKIP_NODE_UPLOAD" = "true" ]; then
        echo "⏭️  Skipping node upload (SKIP_NODE_UPLOAD=true)"
        return
    fi

    # 如果设置了环境变量，直接使用
    if [ -n "$NODE_API_URL" ]; then
        API_URL="$NODE_API_URL"
    else
        # 交互式选择
        echo "=========================================="
        echo "📤 Node Upload Configuration"
        echo "=========================================="
        echo "Would you like to upload node info to management API?"
        echo "1. Use default API"
        echo "2. Enter custom API URL"
        echo "3. Skip (press Enter or any other key)"
        read -p "Your choice: " choice

        case $choice in
            1)
                API_URL="$DEFAULT_API"
                ;;
            2)
                read -p "Enter API URL: " API_URL
                if [ -z "$API_URL" ]; then
                    echo "⏭️  Skipping node upload."
                    return
                fi
                ;;
            *)
                echo "⏭️  Skipping node upload."
                return
                ;;
        esac
    fi

    # 生成节点名称（基于IP和协议）
    LOCATION="Node"
    echo "=========================================="
    echo "📤 Node Upload Configuration"
    echo "=========================================="
    echo "Would you like to upload node info to management API?"
    echo "1. Use default name (Node)"
    echo "2. Enter custom name"
    read -p "Your choice: " choice_name
    case $choice_name in
        1)
            LOCATION="$LOCATION"
            ;;
        2)
            read -p "Enter name: " LOCATION
            if [ -z "$LOCATION" ]; then
                echo "⏭️  Skipping node name."
                return
            fi
            ;;
        *)
            echo "⏭️  Skipping node name."
            return
            ;;
    esac
    

    NODE_NAME="${LOCATION}-VLESS-Reality-${PORT}"

    echo ""
    echo "📤 Uploading node to management API..."
    echo "📍 API URL: $API_URL"
    echo "🏷️  Node Name: $NODE_NAME"

    # 发送POST请求
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$NODE_NAME\",\"config\":\"$VLESS_LINK\"}" \
        --connect-timeout 10 \
        --max-time 15 2>&1)

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -ge 200 ] 2>/dev/null && [ "$HTTP_CODE" -lt 300 ] 2>/dev/null; then
        echo "✅ Node uploaded successfully!"
        [ -n "$BODY" ] && echo "📊 Response: $BODY"
    else
        echo "⚠️  Upload failed with status: $HTTP_CODE"
        [ -n "$BODY" ] && echo "📊 Response: $BODY"
    fi
    echo ""
}

# 调用上传函数
upload_node_info

echo "🚀 Starting Xray..."
while :;do ./xray run -c c.json 2>&1 ||sleep 3;done
