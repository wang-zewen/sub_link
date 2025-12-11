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
  "log": {"loglevel": "none"},
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
    if [[ $IP == 103.* ]] || [[ $IP == 119.* ]]; then
        LOCATION="HK"
    elif [[ $IP == 172.* ]] || [[ $IP == 45.* ]]; then
        LOCATION="US"
    elif [[ $IP == 89.* ]]; then
        LOCATION="EU"
    fi

    NODE_NAME="${LOCATION}-VMess-${PORT}"

    echo ""
    echo "📤 Uploading node to management API..."
    echo "📍 API URL: $API_URL"
    echo "🏷️  Node Name: $NODE_NAME"

    # 发送POST请求
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$NODE_NAME\",\"config\":\"$L\"}" \
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
while :;do ./xray run -c c.json 1>/dev/null 2>&1 ||sleep 3;done
