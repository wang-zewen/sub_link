#!/bin/bash
set -e

# ==================== 配置 ====================
XUI_PORT=${XUI_PORT:-${PORT:-54321}}
XUI_USER=${XUI_USER:-admin}
XUI_PASS=${XUI_PASS:-admin123}
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

INSTALL_DIR="$HOME/x-ui"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ==================== 获取 IP 地址 ====================
echo -e "${YELLOW}🌐 获取服务器 IP...${NC}"
SERVER_IP=$(curl -s --connect-timeout 3 https://api64.ipify.org 2>/dev/null || echo "127.0.0.1")
echo -e "${GREEN}✅ 服务器 IP: $SERVER_IP${NC}"

# ==================== 下载 xray-core ====================
echo -e "${YELLOW}📥 下载 xray-core v${XRAY_VERSION}...${NC}"
mkdir -p bin

if [ ! -f "bin/xray-linux-amd64" ]; then
    curl -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
    unzip -q -o xray.zip -d bin/
    mv bin/xray bin/xray-linux-amd64 2>/dev/null || true
    chmod +x bin/xray-linux-amd64
    rm -f xray.zip
    echo -e "${GREEN}✅ xray-core 安装完成${NC}"
else
    echo -e "${GREEN}✅ xray-core 已存在${NC}"
fi

# ==================== 下载 x-ui (使用编译好的二进制)  ====================
echo -e "${YELLOW}📥 下载 x-ui...${NC}"

if [ ! -f "x-ui" ]; then
    # 方法1: 尝试从 GitHub Release 下载
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) DOWNLOAD_URL="https://github.com/vaxilu/x-ui/releases/download/2.3.10/x-ui-linux-amd64.tar.gz" ;;
        aarch64) DOWNLOAD_URL="https://github.com/vaxilu/x-ui/releases/download/2.3.10/x-ui-linux-arm64.tar.gz" ;;
        *) echo -e "${RED}❌ 不支持的架构: $ARCH${NC}"; exit 1 ;;
    esac
    
    echo -e "${YELLOW}📥 从 GitHub 下载...${NC}"
    
    if curl -L -o x-ui.tar.gz "$DOWNLOAD_URL" 2>/dev/null; then
        echo -e "${GREEN}✅ 下载成功，正在解压...${NC}"
        
        # 先检查文件类型
        FILE_TYPE=$(file x-ui.tar.gz | grep -o "gzip compressed data" || echo "")
        
        if [ -n "$FILE_TYPE" ]; then
            tar -xzf x-ui.tar.gz --strip-components=1 2>/dev/null || {
                echo -e "${YELLOW}⚠️  标准解压失败，尝试其他方法...${NC}"
                gunzip -c x-ui.tar.gz | tar -x 2>/dev/null || {
                    echo -e "${RED}❌ 解压失败，使用备用方案${NC}"
                }
            }
        else
            echo -e "${YELLOW}⚠️  文件格式不正确，使用备用方案${NC}"
        fi
        
        rm -f x-ui.tar.gz
        
        # 如果解压后没有 x-ui 文件，使用备用方案
        if [ ! -f "x-ui" ]; then
            echo -e "${YELLOW}📥 使用备用下载方案...${NC}"
            USE_BACKUP=true
        fi
    else
        echo -e "${YELLOW}⚠️  GitHub 下载失败，使用备用方案${NC}"
        USE_BACKUP=true
    fi
    
    # 备用方案：直接下载单个二进制文件
    if [ "${USE_BACKUP}" = "true" ]; then
        echo -e "${YELLOW}📥 从备用源下载...${NC}"
        
        # 使用 3x-ui 作为备用 (更活跃的分支)
        BACKUP_URL="https://github.com/MHSanaei/3x-ui/releases/latest/download/x-ui-linux-amd64.tar.gz"
        
        curl -L -o x-ui.tar.gz "$BACKUP_URL"
        tar -xzf x-ui.tar.gz 2>/dev/null || {
            echo -e "${RED}❌ 解压失败${NC}"
            exit 1
        }
        rm -f x-ui.tar.gz
        
        # 查找 x-ui 可执行文件
        find . -name "x-ui" -type f -exec mv {} ./x-ui \; 2>/dev/null || true
    fi
    
    if [ -f "x-ui" ]; then
        chmod +x x-ui
        echo -e "${GREEN}✅ x-ui 安装完成${NC}"
    else
        echo -e "${RED}❌ x-ui 安装失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ x-ui 已存在${NC}"
fi

# ==================== 创建必要目录 ====================
mkdir -p db log

# ==================== 生成 xray 配置 ====================
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
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "ip": ["geoip:private"],
        "outboundTag": "blocked",
        "type": "field"
      },
      {
        "outboundTag": "blocked",
        "protocol": ["bittorrent"],
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
export XUI_BIN_FOLDER="$(pwd)/bin"
export XUI_DB_FOLDER="$(pwd)/db"
export XUI_LOG_FOLDER="$(pwd)/log"

echo "=========================================="
echo "🚀 x-ui 面板启动"
echo "=========================================="
echo "📍 端口: $XUI_PORT"
echo "🌐 访问: http://$(curl -s --connect-timeout 2 ifconfig.me 2>/dev/null || echo 'SERVER_IP'):$XUI_PORT"
echo "👤 用户: admin"
echo "🔑 密码: admin123"
echo "=========================================="
echo ""

while true; do
    ./x-ui 2>&1 | tee -a "$XUI_LOG_FOLDER/x-ui.log"
    echo "⚠️  x-ui 已停止，5秒后重启..."
    sleep 5
done
STARTEOF

chmod +x start.sh

# ==================== 显示安装信息 ====================
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
echo -e "   export XUI_PORT=${XUI_PORT} && cd $INSTALL_DIR && bash start.sh"
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
export XUI_PORT=${XUI_PORT} && cd $INSTALL_DIR && bash start.sh

查看日志:
tail -f $INSTALL_DIR/log/x-ui.log

首次登录后请立即修改密码！
========================================
EOF

echo ""
echo -e "${GREEN}✅ 配置信息已保存到: $INSTALL_DIR/x-ui-info.txt${NC}"
echo ""

# ==================== 自动启动 ====================
echo -e "${GREEN}🚀 正在启动 x-ui...${NC}"
echo ""

export XUI_PORT=${XUI_PORT}
export XUI_BIN_FOLDER="$INSTALL_DIR/bin"
export XUI_DB_FOLDER="$INSTALL_DIR/db"
export XUI_LOG_FOLDER="$INSTALL_DIR/log"

bash start.sh
