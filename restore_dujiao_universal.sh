#!/usr/bin/env bash
# 优化版：自动适配本地镜像加载与 tokenpay-docker 路径
set -euo pipefail

VERSION="Dujiao Restore Script v4.0 PRO-MAX"
START_TIME=$(date +%s)

# 颜色定义
BLUE="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# 核心变量配置
NET="dujiao-next_default"
DOM_MAIN="yufu120.de5.net"
DOM_ADMIN="pay.yufu120.de5.net"
LE_LIVE="/etc/letsencrypt/live/${DOM_MAIN}"
CRONFILE="/etc/cron.d/certbot-renew"
# 修正路径：确保与你 VPS 实际路径一致
TP_DATA="/opt/tokenpay-docker/data" 

echo -e "${BLUE}====================================${RESET}"
echo -e "${BLUE}${VERSION}${RESET}"
echo -e "${BLUE}====================================${RESET}"

# 1. 基础环境检查与安装
install_docker_if_needed() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}🐳 开始安装 Docker...${RESET}"
    apt-get update -y && apt-get install -y docker.io docker-compose
    systemctl enable --now docker
    echo -e "${GREEN}✅ Docker 安装完成${RESET}"
  else
    echo -e "${GREEN}✅ Docker 环境就绪${RESET}"
  fi
}

# 2. 恢复文件与镜像（核心修复）
restore_data() {
  # 恢复项目文件
  local BK=$(ls -1 /root/dujiao_full_backup*.tar.gz 2>/dev/null | head -n1 || true)
  if [[ -n "$BK" ]]; then
    echo -e "${BLUE}📦 正在解压备份包...${RESET}"
    tar -xzf "$BK" -C /
    echo -e "${GREEN}✓ 文件已还原至系统目录${RESET}"
  else
    echo -e "${RED}❌ 错误：未发现备份包 /root/dujiao_full_backup*.tar.gz${RESET}"
    exit 1
  fi

  # 恢复本地镜像（解决 pull denied 问题）
  if [[ -f "/root/all_images.tar" ]]; then
    echo -e "${BLUE}🖼️ 正在从本地加载 Docker 镜像...${RESET}"
    docker load -i /root/all_images.tar
    echo -e "${GREEN}✓ 镜像加载完成${RESET}"
  fi
}

# 3. 启动容器阵列
start_containers() {
  echo -e "${BLUE}🚀 正在启动容器服务...${RESET}"
  if ! docker network ls | grep -q "$NET"; then docker network create "$NET"; fi

  # 清理同名旧容器
  docker rm -f tokenpay dujiao-next-redis-1 dujiao-next-api-1 dujiao-next-user-1 dujiao-next-admin-1 dujiao-gw >/dev/null 2>&1 || true

  # 启动 Redis
  docker run -d --name dujiao-next-redis-1 --network "$NET" --network-alias redis \
    -v /opt/dujiao-next/data/redis:/data redis:7-alpine >/dev/null

  # 启动 TokenPay (修正路径并注入 host-gateway)
  docker run -d --name tokenpay --network "$NET" -p 52939:8080 \
    -v "$TP_DATA":/app/data \
    --add-host=host.docker.internal:host-gateway \
    --restart always \
    tokenpay-docker-tokenpay:latest >/dev/null

  # 启动 Dujiao-Next API
  docker run -d --name dujiao-next-api-1 --network "$NET" -p 8080:8080 \
    -v /opt/dujiao-next/data/db:/app/db \
    -v /opt/dujiao-next/config/config.yml:/app/config.yml:ro \
    -v /opt/dujiao-next/data/uploads:/app/uploads \
    dujiaonext/api:latest >/dev/null

  # 启动 User 和 Admin 容器
  docker run -d --name dujiao-next-user-1 --network "$NET" -p 8081:80 dujiaonext/user:latest >/dev/null
  docker run -d --name dujiao-next-admin-1 --network "$NET" -p 8082:80 dujiaonext/admin:latest >/dev/null
}

# 4. 网关与证书配置
start_gateway() {
  if [[ -d "/etc/letsencrypt/live" ]]; then
    echo -e "${GREEN}✓ 加载现有 SSL 证书${RESET}"
    docker run -d --name dujiao-gw --network "$NET" -p 80:80 -p 443:443 \
      -v /opt/dujiao-gw/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
      -v /etc/letsencrypt:/etc/letsencrypt:ro \
      nginx:alpine >/dev/null
  else
    echo -e "${RED}⚠ 未发现 SSL 证书，请解析域名后重新签发${RESET}"
  fi
}

main() {
  install_docker_if_needed
  restore_data
  start_containers
  start_gateway
  
  echo -e "${GREEN}====================================${RESET}"
  echo -e "${GREEN}✅ 独角数卡全线业务已在新服务器复活！${RESET}"
  echo -e "${BLUE}请确保域名 $DOM_MAIN 已指向本机 IP${RESET}"
  docker ps
}

main "$@"
