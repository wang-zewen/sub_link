#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# ==================== 配置 ====================
XUI_PORT=${PORT:-${XUI_PORT:-54321}}
XUI_USER=${XUI_USER:-admin}
XUI_PASS=${XUI_PASS:-admin}

echo -e "${green}========================================${plain}"
echo -e "${green}🚀 x-ui 免 Root 安装脚本${plain}"
echo -e "${green}========================================${plain}"
echo ""

# ==================== 检测架构 ====================
arch=$(arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${yellow}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo -e "${green}架构: ${arch}${plain}"

if [ -n "$PORT" ]; then
    echo -e "${green}✅ 检测到 WispByte 端口: $PORT${plain}"
    XUI_PORT=$PORT
else
    echo -e "${yellow}⚠️  未检测到平台端口，使用: $XUI_PORT${plain}"
fi

# ==================== 设置安装目录 ====================
INSTALL_DIR="$HOME/x-ui"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "${yellow}📍 安装目录: ${INSTALL_DIR}${plain}"

# ==================== 获取服务器 IP ====================
echo -e "${yellow}🌐 获取服务器 IP...${plain}"
SERVER_IP=$(curl -s --connect-timeout 3 https://api64.ipify.org 2>/dev/null || \
            curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null || \
            echo "127.0.0.1")
echo -e "${green}✅ 服务器 IP: ${SERVER_IP}${plain}"

# ==================== 停止旧进程 ====================
pkill -f "x-ui" 2>/dev/null || true
sleep 1

# ==================== 备份旧数据 ====================
if [ -d "x-ui/db" ]; then
    echo -e "${yellow}📦 备份旧数据...${plain}"
    cp -r x-ui/db db_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
fi

# ==================== 清理旧文件 ====================
rm -rf x-ui bin *.tar.gz 2>/dev/null || true

# ==================== 下载 x-ui ====================
echo -e "${yellow}📥 正在下载 x-ui...${plain}"

# 获取最新版本
last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ ! -n "$last_version" ]]; then
    echo -e "${yellow}⚠️  GitHub API 失败，使用固定版本 v0.3.2${plain}"
    last_version="0.3.2"
fi

echo -e "${green}检测到 x-ui 版本：${last_version}${plain}"

# 下载地址
download_url="https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
echo -e "${yellow}📥 下载地址: ${download_url}${plain}"

# 使用 curl 下载（替代 wget）
echo -e "${yellow}📥 使用 curl 下载...${plain}"
curl -L -o x-ui.tar.gz "${download_url}" --progress-bar

if [[ $? -ne 0 ]]; then
    echo -e "${red}❌ 下载失败，尝试备用源...${plain}"
    
    # 尝试 GitHub 代理
    download_url="https://ghproxy.com/https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
    echo -e "${yellow}📥 备用地址: ${download_url}${plain}"
    curl -L -o x-ui.tar.gz "${download_url}" --progress-bar
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}❌ 下载失败，尝试 jsdelivr CDN...${plain}"
        download_url="https://cdn.jsdelivr.net/gh/vaxilu/x-ui@${last_version}/x-ui-linux-${arch}.tar.gz"
        curl -L -o x-ui.tar.gz "${download_url}" --progress-bar
        
        if [[ $? -ne 0 ]]; then
            echo -e "${red}❌ 所有下载源均失败，请检查网络连接${plain}"
            exit 1
        fi
    fi
fi

# 检查下载的文件
if [ ! -f "x-ui.tar.gz" ] || [ ! -s "x-ui.tar.gz" ]; then
    echo -e "${red}❌ 下载的文件无效${plain}"
    exit 1
fi

echo -e "${green}✅ 下载完成，文件大小: $(du -h x-ui.tar.gz | cut -f1)${plain}"

# ==================== 解压并检查结构 ====================
echo -e "${yellow}📦 解压文件...${plain}"

# 解压到当前目录
tar -zxf x-ui.tar.gz 2>&1

if [[ $? -ne 0 ]]; then
    echo -e "${red}❌ 解压失败${plain}"
    
    # 尝试其他解压方式
    echo -e "${yellow}⚠️  尝试 gzip + tar 解压...${plain}"
    gunzip -c x-ui.tar.gz | tar -x 2>&1
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}❌ 解压失败，文件可能已损坏${plain}"
        exit 1
    fi
fi

# 检查解压后的结构
echo -e "${yellow}🔍 检查解压结构...${plain}"
echo "当前目录内容："
ls -la

# 查找 x-ui 可执行文件
XUI_BINARY=$(find . -name "x-ui" -type f 2>/dev/null | head -1)

if [ -n "$XUI_BINARY" ]; then
    echo -e "${green}✅ 找到 x-ui: $XUI_BINARY${plain}"
    
    # 获取 x-ui 所在目录
    XUI_DIR=$(dirname "$XUI_BINARY")
    
    # 如果不在标准位置，移动到标准位置
    if [ "$XUI_DIR" != "./x-ui" ] && [ "$XUI_DIR" != "x-ui" ]; then
        echo -e "${yellow}📦 重组目录结构...${plain}"
        mkdir -p x-ui/bin
        
        # 移动 x-ui 可执行文件
        if [ -f "$XUI_BINARY" ]; then
            mv "$XUI_BINARY" x-ui/
        fi
        
        # 查找并移动 xray
        find . -name "xray*" -type f ! -path "./x-ui/*" -exec mv {} x-ui/bin/ \; 2>/dev/null
        
        # 移动 bin 目录
        if [ -d "bin" ] && [ "bin" != "x-ui/bin" ]; then
            cp -r bin/* x-ui/bin/ 2>/dev/null || true
        fi
        
        XUI_DIR="x-ui"
    elif [ "$XUI_DIR" = "." ]; then
        # 扁平结构，创建标准目录
        echo -e "${yellow}📦 创建标准目录结构...${plain}"
        mkdir -p x-ui/bin
        mv x-ui x-ui/x-ui
        find . -name "xray*" -type f -maxdepth 1 -exec mv {} x-ui/bin/ \; 2>/dev/null
        [ -d "bin" ] && mv bin/* x-ui/bin/ 2>/dev/null || true
        XUI_DIR="x-ui"
    else
        XUI_DIR="x-ui"
    fi
else
    echo -e "${red}❌ 未找到 x-ui 可执行文件${plain}"
    echo -e "${yellow}目录内容：${plain}"
    find . -type f
    exit 1
fi

# 进入 x-ui 目录
cd "$XUI_DIR"
echo -e "${green}✅ 工作目录: $(pwd)${plain}"

# 设置权限
chmod +x x-ui 2>/dev/null || true

# 处理 xray 文件
if [ -d "bin" ]; then
    cd bin
    # 重命名 xray 文件
    for f in xray*; do
        if [ -f "$f" ]; then
            chmod +x "$f"
            # 如果文件名不是标准格式，创建软链接
            if [ "$f" != "xray-linux-${arch}" ]; then
                ln -sf "$f" "xray-linux-${arch}" 2>/dev/null || cp "$f" "xray-linux-${arch}"
            fi
        fi
    done
    cd ..
fi

echo -e "${green}✅ 解压和配置完成${plain}"

# ==================== 创建数据库目录 ====================
mkdir -p db

# 恢复备份的数据库
LATEST_BACKUP=$(ls -td ../db_backup_* 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
    echo -e "${yellow}📦 恢复数据库备份...${plain}"
    cp -r "$LATEST_BACKUP"/* db/ 2>/dev/null || true
    echo -e "${green}✅ 数据库已恢复${plain}"
fi

# ==================== 创建启动脚本 ====================
cat > ../start.sh << STARTEOF
#!/bin/bash
cd "\$(dirname "\$0")/x-ui"

export XUI_BIN_FOLDER="\$(pwd)/bin"
export XUI_DB_FOLDER="\$(pwd)/db"
export XUI_LOG_FOLDER="\$(pwd)"

echo "=========================================="
echo "🚀 x-ui 面板启动中..."
echo "=========================================="
echo "📍 端口: ${XUI_PORT}"
echo "🌐 访问: http://${SERVER_IP}:${XUI_PORT}"
echo "👤 用户: ${XUI_USER}"
echo "🔑 密码: ${XUI_PASS}"
echo "=========================================="
echo ""

# 首次运行时设置
if [ ! -f "db/x-ui.db" ] || [ ! -s "db/x-ui.db" ]; then
    echo "🔧 首次运行，初始化中..."
    timeout 5 ./x-ui > /dev/null 2>&1 || true
    sleep 2
    
    if [ -f "db/x-ui.db" ]; then
        ./x-ui setting -username "${XUI_USER}" -password "${XUI_PASS}" 2>/dev/null || true
        ./x-ui setting -port ${XUI_PORT} 2>/dev/null || true
        echo "✅ 初始化完成"
    fi
fi

echo "🚀 x-ui 正在运行..."
echo "📝 按 Ctrl+C 停止"
echo ""

while true; do
    ./x-ui
    echo ""
    echo "⚠️  x-ui 已停止，5秒后重启..."
    sleep 5
done
STARTEOF

chmod +x ../start.sh

# ==================== 创建管理脚本 ====================
cat > ../x-ui.sh << 'MGMTEOF'
#!/bin/bash
XUI_DIR="$HOME/x-ui/x-ui"

case "$1" in
    start)
        cd "$HOME/x-ui"
        nohup bash start.sh > xui.log 2>&1 &
        echo "✅ x-ui 已后台启动"
        echo "📝 查看日志: tail -f $HOME/x-ui/xui.log"
        ;;
    stop)
        pkill -f "x-ui/x-ui"
        echo "✅ x-ui 已停止"
        ;;
    restart)
        pkill -f "x-ui/x-ui"
        sleep 2
        cd "$HOME/x-ui"
        nohup bash start.sh > xui.log 2>&1 &
        echo "✅ x-ui 已重启"
        ;;
    status)
        if pgrep -f "x-ui/x-ui" > /dev/null; then
            echo "✅ x-ui 正在运行"
        else
            echo "❌ x-ui 未运行"
        fi
        ;;
    log)
        tail -f "$HOME/x-ui/xui.log"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|log}"
        exit 1
        ;;
esac
MGMTEOF

chmod +x ../x-ui.sh

# ==================== 清理 ====================
cd "$INSTALL_DIR"
rm -f x-ui.tar.gz

# ==================== 保存配置 ====================
cat > x-ui-info.txt << EOF
========================================
x-ui 安装信息
========================================
版本: ${last_version}
安装目录: ${INSTALL_DIR}
访问地址: http://${SERVER_IP}:${XUI_PORT}
默认用户: ${XUI_USER}
默认密码: ${XUI_PASS}

管理命令:
  前台: cd ${INSTALL_DIR} && bash start.sh
  后台: ${INSTALL_DIR}/x-ui.sh start
  停止: ${INSTALL_DIR}/x-ui.sh stop
  日志: ${INSTALL_DIR}/x-ui.sh log
========================================
EOF

# ==================== 完成 ====================
echo ""
echo -e "${green}========================================${plain}"
echo -e "${green}🎉 x-ui v${last_version} 安装完成！${plain}"
echo -e "${green}========================================${plain}"
echo ""
echo -e "${yellow}🌐 访问: http://${SERVER_IP}:${XUI_PORT}${plain}"
echo -e "${yellow}👤 用户: ${XUI_USER}${plain}"
echo -e "${yellow}🔑 密码: ${XUI_PASS}${plain}"
echo ""
echo -e "${yellow}🚀 启动: cd ${INSTALL_DIR} && bash start.sh${plain}"
echo -e "${green}========================================${plain}"
echo ""

read -p "是否立即启动? [y/n]: " START_NOW
if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    cd "$INSTALL_DIR"
    bash start.sh
fi
