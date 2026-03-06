#!/usr/bin/env bash
# Dujiao-Next 全自动一键部署/恢复脚本
set -euo pipefail

# 1. 基础配置（在此修改你的域名）
USER_DOMAIN="shop.example.com"
ADMIN_DOMAIN="admin.example.com"
EMAIL="admin@example.com"

# 2. 自动化环境变量
export DEBIAN_FRONTEND=noninteractive
DEPLOY_DIR="/root/dujiao-next-docker"

echo "=> [1/6] 安装系统依赖与 Docker..."
apt-get update -y >/dev/null 2>&1
apt-get install -y curl wget jq nginx openssl unzip >/dev/null 2>&1

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash >/dev/null 2>&1
    systemctl enable docker && systemctl start docker
fi

echo "=> [2/6] 深度清理旧容器冲突..."
# 彻底删除所有残留，确保端口 16379 和 15432 干净
docker rm -f $(docker ps -aq --filter "name=dujiaonext") >/dev/null 2>&1 || true
mkdir -p ${DEPLOY_DIR}/config ${DEPLOY_DIR}/data/redis ${DEPLOY_DIR}/data/postgres ${DEPLOY_DIR}/data/uploads

echo "=> [3/6] 自动生成高强度密钥..."
# 随机生成 JWT Secret，无需人工干预
JWT_SEC=$(openssl rand -base64 32)
U_JWT_SEC=$(openssl rand -base64 32)

echo "=> [4/6] 写入 Docker Compose 配置 (端口避让版)..."
cat > ${DEPLOY_DIR}/docker-compose.yml <<EOF
services:
  redis:
    image: redis:7-alpine
    container_name: dujiaonext-redis
    restart: unless-stopped
    command: ["redis-server", "--requirepass", "dujiao_redis_123456"]
    ports:
      - "127.0.0.1:16379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "dujiao_redis_123456", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - dujiao-net

  postgres:
    image: postgres:16-alpine
    container_name: dujiaonext-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: dujiao_next
      POSTGRES_USER: dujiao
      POSTGRES_PASSWORD: dujiao_postgres_123456
    ports:
      - "127.0.0.1:15432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dujiao -d dujiao_next"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - dujiao-net

  api:
    image: dujiaonext/api:v0.0.8-beta
    container_name: dujiaonext-api
    restart: unless-stopped
    environment:
      DJ_DEFAULT_ADMIN_USERNAME: "111"
      DJ_DEFAULT_ADMIN_PASSWORD: "111"
    ports:
      - "8080:8080"
    volumes:
      - ./config/config.yml:/app/config.yml:ro
      - ./data/uploads:/app/uploads
    depends_on:
      redis: { condition: service_healthy }
      postgres: { condition: service_healthy }
    networks:
      - dujiao-net

networks:
  dujiao-net:
    driver: bridge
EOF

echo "=> [5/6] 写入业务配置文件..."
cat > ${DEPLOY_DIR}/config/config.yml <<EOF
database:
  driver: postgres
  dsn: "host=postgres user=dujiao password=dujiao_postgres_123456 dbname=dujiao_next port=5432 sslmode=disable"
jwt:
  secret: ${JWT_SEC}
user_jwt:
  secret: ${U_JWT_SEC}
redis:
  enabled: true
  host: redis
  port: 6379
  password: "dujiao_redis_123456"
EOF

echo "=> [6/6] 启动服务并静默等待..."
cd ${DEPLOY_DIR}
docker compose pull >/dev/null 2>&1
docker compose up -d

echo "------------------------------------------------"
echo "✅ 部署指令已全部下达！"
echo "管理账号: 111 / 111"
echo "正在等待容器完全就绪 (预计 1-2 分钟)..."
echo "------------------------------------------------"
