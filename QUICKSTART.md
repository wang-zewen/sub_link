# 🚀 快速开始指南

本项目提供多种部署方式，选择最适合你的方式即可。

## 📋 部署方式对比

| 方式 | 优点 | 缺点 | 推荐场景 |
|------|------|------|----------|
| **Shell脚本** | 简单快速，一键部署 | 仅限Linux | Linux服务器 |
| **JavaScript** | 支持多架构，自动检测 | 需要Node.js | Node.js环境 |
| **Java JAR** | 跨平台，单文件部署 | 需要Java 17+ | Windows/Linux/macOS |
| **Docker** | 隔离环境，易于管理 | 需要Docker | 容器化部署 |

## 🎯 推荐部署流程

### 场景1: Linux服务器（最简单）

```bash
# VLESS+Reality（推荐）
bash <(curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vless-reality.sh)

# 或 VMess
bash <(curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vmess.sh)
```

### 场景2: 跨平台部署（Windows/Linux/macOS）

```bash
# 1. 确保安装了Java 17+
java -version

# 2. 下载JAR文件
wget https://github.com/wang-zewen/sub_link/releases/latest/download/vless-reality-server-2.0.0.jar

# 3. 运行
java -jar vless-reality-server-2.0.0.jar

# 查看生成的订阅链接
cat link.txt
```

### 场景3: Docker部署

```bash
# 1. 克隆仓库
git clone https://github.com/wang-zewen/sub_link.git
cd sub_link

# 2. 使用Docker Compose启动
docker-compose up -d

# 3. 查看日志
docker-compose logs -f
```

### 场景4: Node.js环境

```bash
# 下载并运行
curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vless-reality.js -o vless-reality.js
node vless-reality.js
```

## 🔧 自定义配置

所有部署方式都支持通过环境变量自定义配置：

```bash
# 设置端口（默认20041）
export PORT=8443

# 设置UUID（留空自动生成）
export VLESS_UUID=你的UUID

# 设置Reality SNI（仅VLESS+Reality）
export REALITY_SERVER_NAMES=www.cloudflare.com
export REALITY_DEST=www.cloudflare.com:443

# 然后运行对应的部署命令
```

## 📱 获取订阅链接

部署完成后，订阅链接会：
1. 显示在终端输出中
2. 保存到 `link.txt` 文件

```bash
# 查看订阅链接
cat link.txt
```

将这个链接复制到你的客户端（V2RayN、V2RayNG、Shadowrocket等）即可使用。

## 🏗️ 从源码构建JAR

```bash
# 1. 克隆仓库
git clone https://github.com/wang-zewen/sub_link.git
cd sub_link

# 2. 编译（需要Maven）
mvn clean package

# 3. 运行
java -jar target/vless-reality-server-2.0.0.jar
```

## 🔄 后台运行

### Linux - 使用systemd

```bash
# 1. 创建服务文件
sudo nano /etc/systemd/system/vless-reality.service

# 2. 粘贴以下内容
[Unit]
Description=VLESS+Reality Server
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/vless-reality
ExecStart=/usr/bin/java -jar vless-reality-server-2.0.0.jar
Restart=always
Environment="PORT=20041"

[Install]
WantedBy=multi-user.target

# 3. 启动服务
sudo systemctl daemon-reload
sudo systemctl enable vless-reality
sudo systemctl start vless-reality
```

### 使用nohup

```bash
# 后台运行
nohup java -jar vless-reality-server-2.0.0.jar > server.log 2>&1 &

# 查看日志
tail -f server.log
```

### 使用screen

```bash
# 创建会话
screen -S vless

# 运行服务器
java -jar vless-reality-server-2.0.0.jar

# 按 Ctrl+A+D 离开会话
# 重新连接: screen -r vless
```

## ❓ 常见问题

### 1. 端口被占用

```bash
# 检查端口
netstat -tulpn | grep 20041

# 更换端口
PORT=8443 java -jar vless-reality-server-2.0.0.jar
```

### 2. Xray下载失败

```bash
# 手动下载Xray
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip
unzip Xray-linux-64.zip xray
chmod +x xray

# 然后再运行服务器
```

### 3. Java版本不对

```bash
# 检查Java版本
java -version

# 应该是Java 17或更高版本
# 如果版本太低，请升级Java
```

### 4. Docker容器无法启动

```bash
# 查看日志
docker-compose logs

# 重新构建
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 📚 详细文档

- [完整README](README.md) - 项目总览和所有功能
- [Java文档](JAVA_README.md) - Java版本详细说明
- [GitHub仓库](https://github.com/wang-zewen/sub_link) - 源码和更新

## 🆘 获取帮助

如果遇到问题：
1. 查看上面的常见问题
2. 查看详细文档
3. 在GitHub提交Issue

## 📊 性能建议

- 推荐配置: 1核CPU, 512MB内存
- 最小配置: 1核CPU, 256MB内存
- 推荐使用VLESS+Reality协议，更安全更隐蔽
- 使用systemd或Docker进行进程管理
