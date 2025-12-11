# VLESS+Reality & VMess Server - One-Click Deployment 🚀

一键部署 VLESS+Reality 和 VMess 服务器到 WispByte、Render、Railway 等平台。

## ✨ 特性

- 🚀 一键部署，无需复杂配置
- 🔐 自动生成 UUID 和密钥对
- 📱 自动生成订阅链接
- 🛡️ VLESS+Reality 协议，更安全更隐蔽
- 🐳 支持 Docker 容器化部署
- 🔄 自动端口检测
- 📦 支持多种部署方式：Shell、JavaScript、Java、Docker
- ☕ Java版本可执行JAR文件，跨平台运行

## 🎯 支持平台

- [WispByte](https://console.wispbyte.com/)
- Docker
- 任何支持 Node.js、Java 或 Bash 的平台

## 📦 快速部署

### 方式 1: VLESS+Reality (推荐) - Shell 版本

```bash
bash <(curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vless-reality.sh)
```

### 方式 2: VLESS+Reality - Node.js 版本

```bash
curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vless-reality.js -o vless-reality.js
chmod +x vless-reality.js
node vless-reality.js
```

### 方式 3: VMess 协议

```bash
bash <(curl -sL https://raw.githubusercontent.com/wang-zewen/sub_link/main/vmess.sh)
```

### 方式 4: Java JAR 部署 ☕ (推荐用于跨平台)

#### VLESS+Reality

```bash
# 下载预编译的JAR文件
wget https://github.com/wang-zewen/sub_link/releases/latest/download/vless-reality-server-2.0.0.jar

# 运行（需要Java 17+）
java -jar vless-reality-server-2.0.0.jar
```

#### VMess

```bash
# 下载预编译的JAR文件
wget https://github.com/wang-zewen/sub_link/releases/latest/download/vmess-server-2.0.0.jar

# 运行（需要Java 17+）
java -jar vmess-server-2.0.0.jar
```

> 📖 **完整的Java使用文档**: [JAVA_README.md](JAVA_README.md)

### 方式 5: Docker 部署

```bash
# 构建镜像
docker build -t vless-reality https://raw.githubusercontent.com/wang-zewen/sub_link/main/Dockerfile

# 运行容器
docker run -d -p 20041:20041 \
  -e VLESS_UUID=你的UUID \
  -e REALITY_SERVER_NAMES=www.microsoft.com \
  --name vless-server vless-reality
```

## 🔧 环境变量配置

### VLESS+Reality 配置

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `PORT` 或 `SERVER_PORT` | 服务端口 | `20041` |
| `VLESS_UUID` | 客户端 UUID | 自动生成 |
| `REALITY_DEST` | Reality 目标地址 | `www.microsoft.com:443` |
| `REALITY_SERVER_NAMES` | SNI 服务器名称 | `www.microsoft.com` |

### VMess 配置

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `PORT` 或 `SERVER_PORT` | 服务端口 | `20041` |
| `VMESS_UUID` | 客户端 UUID | 自动生成 |

## 📖 使用示例

### 自定义端口和 UUID

```bash
# VLESS+Reality
PORT=8443 VLESS_UUID=你的UUID bash vless-reality.sh

# VMess
PORT=8443 VMESS_UUID=你的UUID bash vmess.sh
```

### 自定义 Reality 配置

```bash
REALITY_SERVER_NAMES=www.cloudflare.com \
REALITY_DEST=www.cloudflare.com:443 \
bash vless-reality.sh
```

## 🐳 Docker Compose

创建 `docker-compose.yml`:

```yaml
version: '3'
services:
  vless-reality:
    build: .
    ports:
      - "20041:20041"
    environment:
      - PORT=20041
      - VLESS_UUID=你的UUID
      - REALITY_SERVER_NAMES=www.microsoft.com
    restart: unless-stopped
```

运行:
```bash
docker-compose up -d
```

## ☕ Java版本

本项目提供完整的Java实现，可以生成独立的可执行JAR文件：

### 特点
- ✅ 纯Java实现，无需Shell脚本
- ✅ 跨平台支持（Windows、Linux、macOS）
- ✅ 单个JAR文件，方便分发
- ✅ 自动构建和发布到GitHub Releases

### 从源码编译

```bash
# 需要Java 17+和Maven
mvn clean package

# 生成的JAR文件位于target目录
ls target/*.jar
```

### GitHub Actions自动发布

项目配置了GitHub Actions工作流，会自动：
- 在每次push时构建JAR
- 创建tag时自动发布到GitHub Releases

创建Release:
```bash
git tag -a v2.0.0 -m "Release version 2.0.0"
git push origin v2.0.0
```

详细文档请查看: [JAVA_README.md](JAVA_README.md)

## 📱 客户端配置

部署完成后，脚本会自动生成订阅链接并保存到 `link.txt` 文件中。

支持的客户端：
- V2RayN (Windows)
- V2RayNG (Android)
- Shadowrocket (iOS)
- Clash
- Qv2ray

## 🔒 安全建议

1. 建议使用 VLESS+Reality 协议，比 VMess 更安全
2. 定期更换 UUID
3. 使用强随机的 ShortId
4. 选择合适的 SNI (如 microsoft.com, cloudflare.com 等大型网站)
5. 不要在同一服务器同时运行多个协议

## 📝 协议对比

| 特性 | VLESS+Reality | VMess |
|------|--------------|-------|
| 安全性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 隐蔽性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 性能 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 配置复杂度 | 中等 | 简单 |

## 🛠️ 故障排除

### Xray 无法启动

```bash
# 检查端口是否被占用
netstat -tulpn | grep 20041

# 查看 Xray 日志
./xray run -c c.json
```

### Docker 构建失败

```bash
# 清理缓存重新构建
docker system prune -a
docker build --no-cache -t vless-reality .
```

## 📄 License

MIT
