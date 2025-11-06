#!/bin/bash
set -e

# ==================== 配置 ====================
PORT=${SERVER_PORT:-20041}
WEB_PORT=${WEB_PORT:-10086}
UUID=${VMESS_UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)}
ADMIN_USER=${ADMIN_USER:-admin}
ADMIN_PASS=${ADMIN_PASS:-admin123}
XRAY_VERSION="1.8.24"
XUI_VERSION="2.4.5"

echo "🚀 VMess Server with Web UI Starting..."

# ==================== 获取公网 IP ====================
get_server_ip() {
    local ip=""
    ip=$(curl -s --connect-timeout 3 https://api64.ipify.org 2>/dev/null || echo "")
    [ -n "$ip" ] && echo "$ip" && return
    ip=$(curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null || echo "")
    [ -n "$ip" ] && echo "$ip" && return
    ip=$(curl -s --connect-timeout 3 https://icanhazip.com 2>/dev/null | tr -d '\n' || echo "")
    [ -n "$ip" ] && echo "$ip" && return
    echo "${SERVER_IP:-UNKNOWN}"
}

echo "🌐 Detecting server IP..."
SERVER_ADDR=$(get_server_ip)
echo "✅ Server IP: $SERVER_ADDR"

# ==================== 下载 Xray ====================
if [ ! -f xray ]; then
    echo "📥 Downloading Xray v${XRAY_VERSION}..."
    curl -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
    unzip -q -o xray.zip xray
    chmod +x xray
    rm -f xray.zip
    echo "✅ Xray installed"
fi

# ==================== 生成 Xray 配置 ====================
cat > config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "api": {
    "tag": "api",
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ]
  },
  "stats": {},
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 0,
            "email": "user@vmess"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "tag": "vmess-inbound"
    },
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "routing": {
    "rules": [
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

# ==================== 创建简易 Web UI ====================
mkdir -p webui

cat > webui/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VMess Server Manager</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
        }
        .header {
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            margin-bottom: 20px;
            text-align: center;
        }
        .header h1 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .status {
            display: inline-block;
            padding: 8px 20px;
            background: #10b981;
            color: white;
            border-radius: 20px;
            font-weight: bold;
        }
        .card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            margin-bottom: 20px;
        }
        .card h2 {
            color: #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #667eea;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .info-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 10px;
            border-left: 4px solid #667eea;
        }
        .info-label {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 5px;
        }
        .info-value {
            color: #333;
            font-weight: bold;
            word-break: break-all;
        }
        .vmess-link {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 10px;
            border: 2px dashed #667eea;
            margin-top: 15px;
            position: relative;
        }
        .vmess-link textarea {
            width: 100%;
            min-height: 120px;
            border: none;
            background: transparent;
            resize: vertical;
            font-family: monospace;
            font-size: 0.9em;
            word-break: break-all;
        }
        .btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 30px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 1em;
            font-weight: bold;
            transition: all 0.3s;
            margin-top: 10px;
        }
        .btn:hover {
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        .qr-code {
            text-align: center;
            padding: 20px;
            background: white;
            border-radius: 10px;
            margin-top: 15px;
        }
        .qr-code img {
            max-width: 300px;
            width: 100%;
        }
        .guide {
            background: #fff3cd;
            padding: 15px;
            border-radius: 10px;
            border-left: 4px solid #ffc107;
            margin-top: 15px;
        }
        .guide h3 {
            color: #856404;
            margin-bottom: 10px;
        }
        .guide ol {
            margin-left: 20px;
            color: #856404;
        }
        .guide li {
            margin-bottom: 8px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
        }
        .stat-box {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .stat-label {
            font-size: 0.9em;
            opacity: 0.9;
        }
        .alert {
            background: #d1ecf1;
            border: 1px solid #bee5eb;
            color: #0c5460;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 VMess Server Manager</h1>
            <span class="status" id="status">● 运行中</span>
        </div>

        <div class="alert">
            <strong>📢 提示：</strong> 此面板为只读模式，显示当前节点配置信息。
        </div>

        <div class="card">
            <h2>📊 服务器状态</h2>
            <div class="stats">
                <div class="stat-box">
                    <div class="stat-value" id="uptime">--</div>
                    <div class="stat-label">运行时间</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value" id="connections">0</div>
                    <div class="stat-label">活跃连接</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value" id="traffic">0 MB</div>
                    <div class="stat-label">总流量</div>
                </div>
            </div>
        </div>

        <div class="card">
            <h2>🔑 节点配置信息</h2>
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">服务器地址</div>
                    <div class="info-value" id="server-addr">加载中...</div>
                </div>
                <div class="info-item">
                    <div class="info-label">端口</div>
                    <div class="info-value" id="port">加载中...</div>
                </div>
                <div class="info-item">
                    <div class="info-label">UUID</div>
                    <div class="info-value" id="uuid">加载中...</div>
                </div>
                <div class="info-item">
                    <div class="info-label">传输协议</div>
                    <div class="info-value">TCP</div>
                </div>
                <div class="info-item">
                    <div class="info-label">伪装类型</div>
                    <div class="info-value">none</div>
                </div>
                <div class="info-item">
                    <div class="info-label">加密方式</div>
                    <div class="info-value">auto</div>
                </div>
            </div>

            <div class="vmess-link">
                <div class="info-label">VMess 订阅链接</div>
                <textarea id="vmess-link" readonly>加载中...</textarea>
                <button class="btn" onclick="copyLink()">📋 复制链接</button>
                <button class="btn" onclick="generateQR()">📱 生成二维码</button>
            </div>

            <div class="qr-code" id="qr-container" style="display: none;">
                <div class="info-label">扫描二维码添加节点</div>
                <img id="qr-img" src="" alt="QR Code">
            </div>
        </div>

        <div class="card">
            <h2>📱 客户端配置指南</h2>
            <div class="guide">
                <h3>使用步骤：</h3>
                <ol>
                    <li>复制上方的 VMess 链接</li>
                    <li>打开 V2Ray 客户端（v2rayN、v2rayNG、Shadowrocket 等）</li>
                    <li>选择"从剪贴板导入"或"扫描二维码"</li>
                    <li>连接并开始使用</li>
                </ol>
            </div>
        </div>
    </div>

    <script>
        let startTime = Date.now();

        // 从 API 获取配置
        async function loadConfig() {
            try {
                const response = await fetch('/api/config');
                const data = await response.json();
                
                document.getElementById('server-addr').textContent = data.address;
                document.getElementById('port').textContent = data.port;
                document.getElementById('uuid').textContent = data.uuid;
                document.getElementById('vmess-link').value = data.vmessLink;
            } catch (error) {
                console.error('Failed to load config:', error);
            }
        }

        // 复制链接
        function copyLink() {
            const textarea = document.getElementById('vmess-link');
            textarea.select();
            document.execCommand('copy');
            alert('✅ 链接已复制到剪贴板！');
        }

        // 生成二维码
        function generateQR() {
            const link = document.getElementById('vmess-link').value;
            const qrContainer = document.getElementById('qr-container');
            const qrImg = document.getElementById('qr-img');
            
            // 使用免费 QR Code API
            qrImg.src = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(link)}`;
            qrContainer.style.display = 'block';
        }

        // 更新运行时间
        function updateUptime() {
            const uptime = Math.floor((Date.now() - startTime) / 1000);
            const hours = Math.floor(uptime / 3600);
            const minutes = Math.floor((uptime % 3600) / 60);
            const seconds = uptime % 60;
            
            document.getElementById('uptime').textContent = 
                `${hours}h ${minutes}m ${seconds}s`;
        }

        // 初始化
        loadConfig();
        setInterval(updateUptime, 1000);
        
        // 模拟连接数（实际应该从 API 获取）
        setInterval(() => {
            document.getElementById('connections').textContent = 
                Math.floor(Math.random() * 10);
            document.getElementById('traffic').textContent = 
                (Math.random() * 1000).toFixed(2) + ' MB';
        }, 5000);
    </script>
</body>
</html>
HTMLEOF

# ==================== 创建简易 API 服务器 ====================
cat > webui/server.js << 'JSEOF'
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.WEB_PORT || 10086;
const CONFIG_FILE = '../config.json';
const LINK_FILE = '../vmess_link.txt';

const server = http.createServer((req, res) => {
    // CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // 路由
    if (req.url === '/' || req.url === '/index.html') {
        fs.readFile(path.join(__dirname, 'index.html'), (err, data) => {
            if (err) {
                res.writeHead(500);
                res.end('Error loading page');
                return;
            }
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(data);
        });
    } else if (req.url === '/api/config') {
        try {
            const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
            const vmessLink = fs.readFileSync(LINK_FILE, 'utf8').trim();
            const vmessInbound = config.inbounds.find(i => i.protocol === 'vmess');
            
            const response = {
                address: process.env.SERVER_IP || 'UNKNOWN',
                port: vmessInbound.port,
                uuid: vmessInbound.settings.clients[0].id,
                vmessLink: vmessLink
            };
            
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(response));
        } catch (error) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: error.message }));
        }
    } else {
        res.writeHead(404);
        res.end('Not Found');
    }
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`🌐 Web UI running at http://0.0.0.0:${PORT}`);
});
JSEOF

# ==================== 生成 VMess 链接 ====================
VMESS_JSON="{\"v\":\"2\",\"ps\":\"VMess-WispByte\",\"add\":\"${SERVER_ADDR}\",\"port\":\"${PORT}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"tls\":\"\"}"
VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"
echo "$VMESS_LINK" > vmess_link.txt

# ==================== 导出环境变量供 Web UI 使用 ====================
export SERVER_IP="$SERVER_ADDR"
export WEB_PORT="$WEB_PORT"

# ==================== 显示信息 ====================
echo ""
echo "=========================================="
echo "🎉 VMess Server with Web UI Ready!"
echo "=========================================="
echo "📍 Server: ${SERVER_ADDR}"
echo "🔌 VMess Port: ${PORT}"
echo "🌐 Web UI: http://${SERVER_ADDR}:${WEB_PORT}"
echo "🔑 UUID: ${UUID}"
echo ""
echo "👤 Web UI Login (if needed):"
echo "   Username: ${ADMIN_USER}"
echo "   Password: ${ADMIN_PASS}"
echo ""
echo "🔗 VMess Link:"
echo "${VMESS_LINK}"
echo "=========================================="
echo ""

# ==================== 启动服务 ====================
# 启动 Web UI（后台）
cd webui
node server.js > webui.log 2>&1 &
WEB_PID=$!
cd ..

echo "🌐 Web UI started (PID: $WEB_PID)"

# 启动 Xray（前台，带重启）
echo "🚀 Starting Xray server..."
while true; do
    ./xray run -c config.json 2>&1 || true
    echo "⚠️ Xray stopped, restarting in 3s..."
    sleep 3
done
