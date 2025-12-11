#!/bin/bash

# VLESS+Reality 一键安装脚本
# 支持多种部署方式

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "======================================"
echo "  VLESS+Reality 一键安装脚本"
echo "======================================"
echo -e "${NC}"

# 检测环境
echo -e "${YELLOW}检测系统环境...${NC}"

# 检查是否安装了 curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: 未检测到 curl，正在安装...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y curl
    elif command -v yum &> /dev/null; then
        yum install -y curl
    else
        echo -e "${RED}无法自动安装 curl，请手动安装后重试${NC}"
        exit 1
    fi
fi

# 选择部署方式
echo ""
echo -e "${GREEN}请选择部署方式:${NC}"
echo "1) Shell 脚本 (推荐，无需 Node.js)"
echo "2) Node.js 脚本"
echo "3) Docker 部署"
echo "4) Docker Compose 部署"
echo ""
read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        echo -e "${GREEN}使用 Shell 脚本部署...${NC}"
        curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vless-reality.sh -o vless-reality.sh
        chmod +x vless-reality.sh
        ./vless-reality.sh
        ;;
    2)
        echo -e "${GREEN}使用 Node.js 脚本部署...${NC}"
        if ! command -v node &> /dev/null; then
            echo -e "${RED}错误: 未检测到 Node.js，请先安装 Node.js${NC}"
            exit 1
        fi
        curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vless-reality.js -o vless-reality.js
        chmod +x vless-reality.js
        node vless-reality.js
        ;;
    3)
        echo -e "${GREEN}使用 Docker 部署...${NC}"
        if ! command -v docker &> /dev/null; then
            echo -e "${RED}错误: 未检测到 Docker，请先安装 Docker${NC}"
            exit 1
        fi

        read -p "请输入端口 (默认 20041): " port
        port=${port:-20041}

        read -p "请输入 UUID (留空自动生成): " uuid

        docker build -t vless-reality https://github.com/wang-zewen/sub_link.git

        if [ -z "$uuid" ]; then
            docker run -d -p ${port}:${port} --name vless-server vless-reality
        else
            docker run -d -p ${port}:${port} -e VLESS_UUID=${uuid} --name vless-server vless-reality
        fi

        echo -e "${GREEN}Docker 容器已启动${NC}"
        docker logs vless-server
        ;;
    4)
        echo -e "${GREEN}使用 Docker Compose 部署...${NC}"
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
            echo -e "${RED}错误: 未检测到 Docker Compose，请先安装${NC}"
            exit 1
        fi

        # 下载必要文件
        curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/docker-compose.yml -o docker-compose.yml
        curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/Dockerfile -o Dockerfile
        curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vless-reality.js -o vless-reality.js
        curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vless-reality.sh -o vless-reality.sh
        curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/package.json -o package.json

        chmod +x vless-reality.js vless-reality.sh

        # 启动
        if command -v docker-compose &> /dev/null; then
            docker-compose up -d
        else
            docker compose up -d
        fi

        echo -e "${GREEN}Docker Compose 部署完成${NC}"
        echo -e "${YELLOW}查看日志: docker-compose logs -f${NC}"
        ;;
    *)
        echo -e "${RED}无效的选项${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}======================================"
echo "  安装完成！"
echo "======================================${NC}"
echo -e "${YELLOW}订阅链接已保存到 link.txt 文件${NC}"
