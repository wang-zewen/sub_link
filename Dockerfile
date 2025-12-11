# VLESS+Reality Server Docker Image
FROM node:20-alpine

# 安装必要的工具
RUN apk add --no-cache \
    bash \
    curl \
    unzip \
    openssl \
    util-linux \
    ca-certificates

# 创建工作目录
WORKDIR /app

# 复制项目文件
COPY package.json ./
COPY vless-reality.js ./
COPY vless-reality.sh ./

# 设置脚本可执行权限
RUN chmod +x vless-reality.js vless-reality.sh

# 暴露端口（默认 20041，可通过环境变量修改）
EXPOSE 20041

# 环境变量配置
ENV PORT=20041
ENV NODE_ENV=production

# 默认使用 Node.js 启动
# 如需使用 Shell 脚本，可以覆盖 CMD 为: ["/app/vless-reality.sh"]
CMD ["node", "vless-reality.js"]
