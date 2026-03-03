#!/usr/bin/env bash
set -euo pipefail

VERSION="Dujiao Restore Script v3.1 PRO"
START_TIME=$(date +%s)

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[36m"
RESET="\033[0m"

NET="dujiao-next_default"
CFG="/opt/dujiao-next/config/config.yml"
DOM_MAIN="yufu120.de5.net"
DOM_ADMIN="pay.yufu120.de5.net"
LE_LIVE="/etc/letsencrypt/live/${DOM_MAIN}"
CRONFILE="/etc/cron.d/certbot-renew"

echo -e "${BLUE}====================================${RESET}"
echo -e "${BLUE}${VERSION}${RESET}"
echo -e "${BLUE}====================================${RESET}"

install_docker_if_needed() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}🐳 未检测到 Docker，开始自动安装...${RESET}"

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io

    systemctl enable docker >/dev/null 2>&1 || true
    systemctl start docker  >/dev/null 2>&1 || true

    echo -e "${GREEN}✅ Docker 安装完成${RESET}"
  else
    echo -e "${GREEN}✅ Docker 已安装${RESET}"
  fi
}

detect_public_ip() {
  curl -4 -fsS https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

port_check() {
  if ss -lnt | grep -qE ':(80|443)\b'; then
    echo -e "${YELLOW}⚠ 80/443 端口已被占用：${RESET}"
    ss -lnt | grep -E ':(80|443)\b' || true
    echo -e "${RED}请先释放 80/443 后再恢复（或用测试模式不启动网关）${RESET}"
    exit 1
  fi
  echo -e "${GREEN}✓ 80/443 端口空闲${RESET}"
}

ensure_network() {
  if ! docker network ls --format '{{.Name}}' | grep -qx "$NET"; then
    docker network create "$NET" >/dev/null
  fi
}

redis_alias_fix() {
  # 确保 redis 容器在网络内带 alias=redis，避免 lookup redis 失败
  if docker ps --format '{{.Names}}' | grep -qx "dujiao-next-redis-1"; then
    docker network disconnect "$NET" dujiao-next-redis-1 >/dev/null 2>&1 || true
    docker network connect --alias redis "$NET" dujiao-next-redis-1 >/dev/null 2>&1 || true
  fi
}

ensure_certificate() {
  # 如果你是“迁移自用”，通常会带着 /etc/letsencrypt 过来，这里只做检查提示
  if [[ -f "${LE_LIVE}/fullchain.pem" && -f "${LE_LIVE}/privkey.pem" ]]; then
    echo -e "${GREEN}✓ 发现现有证书${RESET}"
  else
    echo -e "${YELLOW}⚠ 未发现现有证书：${LE_LIVE}${RESET}"
    echo -e "${YELLOW}   你需要先把域名解析到本机，再手动申请证书（或把旧证书备份带过来）${RESET}"
  fi
}

ensure_cron() {
  # 配置每天 03:10 自动续签（续签时停/启网关释放 80）
  cat >"$CRONFILE" <<'EOF'
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
10 3 * * * root certbot renew --quiet \
  --pre-hook "docker stop dujiao-gw >/dev/null 2>&1 || true" \
  --post-hook "docker start dujiao-gw >/dev/null 2>&1 || true"
EOF
  chmod 644 "$CRONFILE"
  systemctl restart cron >/dev/null 2>&1 || true
  echo -e "${GREEN}✓ 已配置续签任务：${CRONFILE}${RESET}"
}

restore_files() {
  # 找备份包（兼容你的两种命名）
  local BK=""
  BK="$(ls -1 /root/dujiao_full_backup*.tar.gz 2>/dev/null | head -n1 || true)"
  if [[ -z "$BK" ]]; then
    echo -e "${RED}❌ 未找到备份包：/root/dujiao_full_backup*.tar.gz${RESET}"
    exit 1
  fi

  echo -e "${BLUE}📦 使用备份包：$BK${RESET}"
  tar -xzf "$BK" -C /
  echo -e "${GREEN}✓ 文件已解压到系统目录${RESET}"
}

pull_images() {
  docker pull nginx:alpine >/dev/null
  docker pull redis:7-alpine >/dev/null
  docker pull dujiaonext/api:latest >/dev/null
  docker pull dujiaonext/user:latest >/dev/null
  docker pull dujiaonext/admin:latest >/dev/null
  docker pull dapiaoliang666/tokenpay:latest >/dev/null
}

start_containers() {
  ensure_network

  # 清理同名容器（避免重复）
  docker rm -f dujiao-next-redis-1 dujiao-next-api-1 dujiao-next-user-1 dujiao-next-admin-1 tokenpay dujiao-gw >/dev/null 2>&1 || true

  docker run -d --name dujiao-next-redis-1 --network "$NET" --network-alias redis \
    -v /opt/dujiao-next/data/redis:/data redis:7-alpine >/dev/null

  docker run -d --name dujiao-next-api-1 --network "$NET" -p 8080:8080 \
    -v /opt/dujiao-next/data/logs:/app/logs \
    -v /opt/dujiao-next/config/config.yml:/app/config.yml:ro \
    -v /opt/dujiao-next/data/db:/app/db \
    -v /opt/dujiao-next/data/uploads:/app/uploads \
    dujiaonext/api:latest >/dev/null

  docker run -d --name dujiao-next-user-1 --network "$NET" -p 8081:80 \
    dujiaonext/user:latest >/dev/null

  docker run -d --name dujiao-next-admin-1 --network "$NET" -p 8082:80 \
    dujiaonext/admin:latest >/dev/null

  docker run -d --name tokenpay --network "$NET" -p 52939:8080 \
    -v /opt/tokenpay:/data \
    -v /opt/tokenpay/appsettings.json:/app/appsettings.json \
    dapiaoliang666/tokenpay:latest >/dev/null

  redis_alias_fix
}

start_gateway_if_possible() {
  # 网关需要 80/443 空闲
  port_check

  docker run -d --name dujiao-gw --network "$NET" -p 80:80 -p 443:443 \
    -v /opt/dujiao-gw/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
    -v /etc/letsencrypt:/etc/letsencrypt:ro \
    nginx:alpine >/dev/null
}

main() {
  install_docker_if_needed
  restore_files
  pull_images
  start_containers

  # 默认：稳定增强版（自用迁移）= 启动网关 + 证书检查 + 续签任务
  ensure_certificate
  ensure_cron
  start_gateway_if_possible

  echo -e "${GREEN}✅ 恢复完成${RESET}"
  docker ps

  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  echo -e "${BLUE}总耗时：${ELAPSED} 秒${RESET}"
}

main "$@"
