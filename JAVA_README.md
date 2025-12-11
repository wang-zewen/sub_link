# Xray Proxy Server - Java Edition ☕

Java版本的VLESS+Reality和VMess代理服务器，提供可执行JAR文件，一键部署。

## ✨ 特性

- ☕ 纯Java实现，跨平台运行
- 📦 单个可执行JAR文件，无需额外依赖
- 🚀 自动下载和配置Xray
- 🔐 自动生成UUID和Reality密钥对
- 📱 自动生成订阅链接
- 🛡️ 支持VLESS+Reality和VMess协议
- 🔄 自动端口检测和故障恢复

## 📋 系统要求

- Java 17 或更高版本
- Linux系统（支持x64, ARM64等架构）
- 至少512MB内存

## 📦 快速部署

### 方式 1: 使用预编译的JAR文件（推荐）

#### VLESS+Reality

```bash
# 下载JAR文件
wget https://github.com/wang-zewen/sub_link/releases/latest/download/vless-reality-server-2.0.0.jar

# 运行
java -jar vless-reality-server-2.0.0.jar
```

#### VMess

```bash
# 下载JAR文件
wget https://github.com/wang-zewen/sub_link/releases/latest/download/vmess-server-2.0.0.jar

# 运行
java -jar vmess-server-2.0.0.jar
```

### 方式 2: 从源码编译

```bash
# 克隆仓库
git clone https://github.com/wang-zewen/sub_link.git
cd sub_link

# 使用Maven编译
mvn clean package

# 运行VLESS+Reality
java -jar target/vless-reality-server-2.0.0.jar

# 或运行VMess
java -jar target/vmess-server-2.0.0.jar
```

## 🔧 环境变量配置

### VLESS+Reality 配置

```bash
# 设置端口
export PORT=8443

# 设置UUID
export VLESS_UUID=你的UUID

# 设置Reality SNI
export REALITY_SERVER_NAMES=www.cloudflare.com

# 设置Reality目标
export REALITY_DEST=www.cloudflare.com:443

# 运行
java -jar vless-reality-server-2.0.0.jar
```

### VMess 配置

```bash
# 设置端口
export PORT=8443

# 设置UUID
export VMESS_UUID=你的UUID

# 运行
java -jar vmess-server-2.0.0.jar
```

## 🐳 Docker部署（Java版本）

### 使用Dockerfile

创建 `Dockerfile.java`:

```dockerfile
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# 安装必要工具
RUN apk add --no-cache bash curl unzip

# 复制JAR文件
COPY target/vless-reality-server-*.jar /app/server.jar

# 暴露端口
EXPOSE 20041

# 运行
CMD ["java", "-jar", "server.jar"]
```

构建和运行:

```bash
docker build -f Dockerfile.java -t vless-reality-java .
docker run -d -p 20041:20041 -e VLESS_UUID=你的UUID vless-reality-java
```

## 📖 使用示例

### 基本使用

```bash
# 使用默认配置运行VLESS+Reality
java -jar vless-reality-server-2.0.0.jar
```

### 自定义端口

```bash
# 运行在8443端口
PORT=8443 java -jar vless-reality-server-2.0.0.jar
```

### 指定UUID

```bash
# 使用指定的UUID
VLESS_UUID=9afd1229-b893-40c1-84dd-51e7ce204913 java -jar vless-reality-server-2.0.0.jar
```

### 完整配置示例

```bash
PORT=8443 \
VLESS_UUID=9afd1229-b893-40c1-84dd-51e7ce204913 \
REALITY_SERVER_NAMES=www.microsoft.com \
REALITY_DEST=www.microsoft.com:443 \
java -jar vless-reality-server-2.0.0.jar
```

## 🔨 Maven构建命令

```bash
# 清理并编译
mvn clean compile

# 运行测试
mvn test

# 打包JAR文件
mvn package

# 清理、编译、测试、打包
mvn clean install

# 跳过测试打包
mvn clean package -DskipTests
```

构建完成后，会在 `target/` 目录生成两个JAR文件：
- `vmess-server-2.0.0.jar` - VMess服务器
- `vless-reality-server-2.0.0.jar` - VLESS+Reality服务器

## 🚀 后台运行

### 使用nohup

```bash
# VLESS+Reality
nohup java -jar vless-reality-server-2.0.0.jar > server.log 2>&1 &

# 查看日志
tail -f server.log
```

### 使用systemd

创建 `/etc/systemd/system/vless-reality.service`:

```ini
[Unit]
Description=VLESS+Reality Proxy Server
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/vless-reality
ExecStart=/usr/bin/java -jar /opt/vless-reality/vless-reality-server-2.0.0.jar
Restart=always
RestartSec=3

Environment="PORT=20041"
Environment="VLESS_UUID=你的UUID"

[Install]
WantedBy=multi-user.target
```

启动服务:

```bash
sudo systemctl daemon-reload
sudo systemctl enable vless-reality
sudo systemctl start vless-reality
sudo systemctl status vless-reality
```

## 📱 客户端配置

部署完成后，服务器会自动生成订阅链接并保存到 `link.txt` 文件中。

```bash
# 查看订阅链接
cat link.txt
```

## 🔍 调试和故障排除

### 查看详细日志

```bash
# 启用详细日志
java -Dorg.slf4j.simpleLogger.defaultLogLevel=debug -jar vless-reality-server-2.0.0.jar
```

### 检查Java版本

```bash
java -version
# 应显示 Java 17 或更高版本
```

### 端口被占用

```bash
# 检查端口占用
netstat -tulpn | grep 20041

# 更换端口
PORT=8443 java -jar vless-reality-server-2.0.0.jar
```

### Xray下载失败

如果Xray自动下载失败，可以手动下载：

```bash
# 下载Xray
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip

# 解压
unzip Xray-linux-64.zip xray

# 设置权限
chmod +x xray

# 然后运行JAR
java -jar vless-reality-server-2.0.0.jar
```

## 🏗️ 项目结构

```
.
├── pom.xml                                    # Maven配置
├── src/
│   └── main/
│       └── java/
│           └── com/
│               └── proxy/
│                   ├── vmess/
│                   │   └── VMessServer.java          # VMess服务器实现
│                   └── vless/
│                       └── VLessRealityServer.java   # VLESS+Reality服务器实现
├── target/
│   ├── vmess-server-2.0.0.jar                # VMess JAR文件
│   └── vless-reality-server-2.0.0.jar        # VLESS+Reality JAR文件
└── .github/
    └── workflows/
        └── build-and-release.yml              # GitHub Actions配置
```

## 🤝 GitHub Actions自动构建

项目配置了GitHub Actions工作流，会自动：

1. ✅ 在每次push到main分支时构建JAR
2. ✅ 在创建tag时自动发布Release
3. ✅ 上传JAR文件到GitHub Releases

### 创建Release

```bash
# 创建tag并推送
git tag -a v2.0.0 -m "Release version 2.0.0"
git push origin v2.0.0
```

GitHub Actions会自动构建并发布JAR文件到Releases页面。

## 🔒 安全建议

1. 建议使用VLESS+Reality协议，比VMess更安全
2. 定期更换UUID和Reality密钥
3. 使用强随机的ShortId
4. 选择合适的SNI（如microsoft.com, cloudflare.com等大型网站）
5. 使用systemd或supervisor进行进程管理
6. 配置防火墙规则

## 📝 环境变量列表

| 变量名 | 说明 | 默认值 | 适用协议 |
|--------|------|--------|----------|
| `PORT` | 服务端口 | `20041` | 两者 |
| `SERVER_PORT` | 服务端口（备选） | `20041` | 两者 |
| `VLESS_UUID` | VLESS客户端UUID | 自动生成 | VLESS |
| `VMESS_UUID` | VMess客户端UUID | 自动生成 | VMess |
| `REALITY_DEST` | Reality目标地址 | `www.microsoft.com:443` | VLESS |
| `REALITY_SERVER_NAMES` | SNI服务器名称 | `www.microsoft.com` | VLESS |

## 📄 License

MIT

## 🙏 致谢

- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) - Xray核心
- Maven生态系统
- Java社区
