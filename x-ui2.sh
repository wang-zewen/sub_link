#!/bin/bash
set -e

# ==================== 配置 ====================
XUI_PORT=${XUI_PORT:-${PORT:-54321}}  # 自动检测端口
XUI_USER=${XUI_USER:-admin}
XUI_PASS=${XUI_PASS:-admin123}
XUI_VERSION="2.3.10"
XRAY_VERSION="1.8.24"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🚀 x-ui 免 Root 安装脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ==================== 检测环境 ====================
echo -e "${YELLOW}📋 检测运行环境...${NC}"

# 检查是否有 root 权限
if [ "$EUID" -eq 0 ]; then 
    echo -e "${GREEN}✅ 检测到 root 权限${NC}"
    HAS_ROOT=true
    INSTALL_DIR="/usr/local/x-ui"
else
    echo -e "${YELLOW}⚠️  无 root 权限，使用用户目录安装${NC}"
    HAS_ROOT=false
    INSTALL_DIR="$HOME/x-ui"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ==================== 获取 IP 地址 ====================
echo -e "${YELLOW}🌐 获取服务器 IP...${NC}"
SERVER_IP=$(curl -s --connect-timeout 3 https://api64.ipify.org 2>/dev/null || \
            curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null || \
            curl -s --connect-timeout 3 https://icanhazip.com 2>/dev/null | tr -d '\n' || \
            echo "127.0.0.1")
echo -e "${GREEN}✅ 服务器 IP: $SERVER_IP${NC}"

# ==================== 下载 x-ui ====================
if [ ! -f "x-ui" ]; then
    echo -e "${YELLOW}📥 下载 x-ui v${XUI_VERSION}...${NC}"
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH_NAME="amd64" ;;
        aarch64) ARCH_NAME="arm64" ;;
        armv7l) ARCH_NAME="armv7" ;;
        *) echo -e "${RED}❌ 不支持的架构: $ARCH${NC}"; exit 1 ;;
    esac
    
    XUI_URL="https://github.com/vaxilu/x-ui/releases/download/${XUI_VERSION}/x-ui-linux-${ARCH_NAME}.tar.gz"
    
    curl -L -o x-ui.tar.gz "$XUI_URL" || {
        echo -e "${RED}❌ 下载失败，尝试备用地址...${NC}"
        XUI_URL="https://github.com/alireza0/x-ui/releases/latest/download/x-ui-linux-${ARCH_NAME}.tar.gz"
        curl -L -o x-ui.tar.gz "$XUI_URL"
    }
    
    tar -zxvf x-ui.tar.gz
    chmod +x x-ui
    rm -f x-ui.tar.gz
    echo -e "${GREEN}✅ x-ui 下载完成${NC}"
else
    echo -e "${GREEN}✅ x-ui 已存在${NC}"
fi

# ==================== 下载 xray-core ====================
if [ ! -f "bin/xray-linux-amd64" ]; then
    echo -e "${YELLOW}📥 下载 xray-core v${XRAY_VERSION}...${NC}"
    mkdir -p bin
    
    curl -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
    unzip -o xray.zip -d bin/
    mv bin/xray bin/xray-linux-amd64 2>/dev/null || true
    chmod +x bin/xray-linux-amd64
    rm -f xray.zip
    echo -e "${GREEN}✅ xray-core 下载完成${NC}"
else
    echo -e "${GREEN}✅ xray-core 已存在${NC}"
fi

# ==================== 创建数据库目录 ====================
mkdir -p db

# ==================== 生成配置文件 ====================
echo -e "${YELLOW}⚙️  生成配置文件...${NC}"

cat > config.json << EOF
{
  "log": {
    "loglevel": "info"
  },
  "api": {
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ],
    "tag": "api"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 62789,
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
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "policy": {
    "system": {
      "statsInboundDownlink": true,
      "statsInboundUplink": true,
      "statsOutboundDownlink": true,
      "statsOutboundUplink": true
    }
  },
  "routing": {
    "rules": [
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked",
        "type": "field"
      },
      {
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ],
        "type": "field"
      }
    ]
  },
  "stats": {}
}
EOF

# ==================== 创建启动脚本 ====================
cat > start.sh << 'STARTEOF'
#!/bin/bash
cd "$(dirname "$0")"

export XUI_PORT=${XUI_PORT:-54321}
export XUI_BIN_FOLDER="./bin"
export XUI_DB_FOLDER="./db"
export XUI_LOG_FOLDER="./log"

mkdir -p "$XUI_LOG_FOLDER"

echo "🚀 启动 x-ui..."
echo "📍 端口: $XUI_PORT"
echo "🌐 访问: http://$(curl -s ifconfig.me):$XUI_PORT"
echo ""

while true; do
    ./x-ui 2>&1 | tee -a "$XUI_LOG_FOLDER/x-ui.log"
    echo "⚠️  x-ui 已停止，5秒后重启..."
    sleep 5
done
STARTEOF

chmod +x start.sh

# ==================== 创建环境变量文件 ====================
cat > .env << EOF
XUI_PORT=${XUI_PORT}
XUI_BIN_FOLDER=${INSTALL_DIR}/bin
XUI_DB_FOLDER=${INSTALL_DIR}/db
XUI_LOG_FOLDER=${INSTALL_DIR}/log
EOF

# ==================== 显示配置信息 ====================
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🎉 x-ui 安装完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📍 安装目录:${NC} $INSTALL_DIR"
echo -e "${YELLOW}🌐 访问地址:${NC} http://${SERVER_IP}:${XUI_PORT}"
echo -e "${YELLOW}👤 默认用户:${NC} ${XUI_USER}"
echo -e "${YELLOW}🔑 默认密码:${NC} ${XUI_PASS}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}🚀 启动命令:${NC}"
echo ""
echo -e "   cd $INSTALL_DIR && bash start.sh"
echo ""
echo -e "${YELLOW}📝 查看日志:${NC}"
echo -e "   tail -f $INSTALL_DIR/log/x-ui.log"
echo ""
echo -e "${BLUE}========================================${NC}"

# ==================== 保存配置信息 ====================
cat > x-ui-info.txt << EOF
========================================
x-ui 安装信息
========================================
访问地址: http://${SERVER_IP}:${XUI_PORT}
默认用户: ${XUI_USER}
默认密码: ${XUI_PASS}

安装目录: $INSTALL_DIR

启动命令:
cd $INSTALL_DIR && bash start.sh

停止命令:
pkill -f x-ui

查看日志:
tail -f $INSTALL_DIR/log/x-ui.log

首次登录后请立即修改密码！
========================================
EOF

echo -e "${GREEN}✅ 配置信息已保存到: x-ui-info.txt${NC}"
echo ""

# ==================== 询问是否立即启动 ====================
read -p "是否立即启动 x-ui? (y/n): " START_NOW

if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    export XUI_PORT=${XUI_PORT}
    export XUI_BIN_FOLDER="${INSTALL_DIR}/bin"
    export XUI_DB_FOLDER="${INSTALL_DIR}/db"
    export XUI_LOG_FOLDER="${INSTALL_DIR}/log"
    
    echo ""
    echo -e "${GREEN}🚀 正在启动 x-ui...${NC}"
    echo ""
    
    bash start.sh
else
    echo ""
    echo -e "${YELLOW}📝 稍后手动启动:${NC}"
    echo -e "   cd $INSTALL_DIR && bash start.sh"
    echo ""
fi
