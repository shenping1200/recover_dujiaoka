#!/usr/bin/env bash
set -euo pipefail

VERSION="Dujiao Restore Script v3.0 PRO"
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

echo -e "${BLUE}========================================${RESET}"
echo -e "${BLUE}${VERSION}${RESET}"
echo -e "${BLUE}========================================${RESET}"

detect_public_ip() {
  curl -4 -fsS https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

port_check() {
  if ss -lnt | grep -qE ':(80|443)\b'; then
    echo -e "${YELLOW}⚠ 80或443端口已被占用${RESET}"
    ss -lnt | grep -E ':(80|443)\b'
  else
    echo -e "${GREEN}✅ 80/443端口空闲${RESET}"
  fi
}

safe_rm(){ docker rm -f "$1" >/dev/null 2>&1 || true; }

ensure_network(){
  docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null
}

ensure_certbot(){
  command -v certbot >/dev/null 2>&1 || (apt-get update -y >/dev/null && apt-get install -y certbot >/dev/null)
}

ensure_certificate(){
  if [[ -f "${LE_LIVE}/fullchain.pem" ]]; then
    echo -e "${GREEN}✅ 发现现有证书${RESET}"
  else
    echo -e "${YELLOW}⚠ 未发现证书，开始自动申请${RESET}"
    ensure_certbot
    timeout 120 certbot certonly \
      --standalone \
      --non-interactive \
      --agree-tos \
      --register-unsafely-without-email \
      --preferred-challenges http \
      --keep-until-expiring \
      -d "${DOM_MAIN}" \
      -d "${DOM_ADMIN}" \
      --quiet || {
        echo -e "${RED}❌ 证书申请失败（请确认DNS已指向本机）${RESET}"
        exit 1
      }
    echo -e "${GREEN}✅ 证书申请完成${RESET}"
  fi
}

ensure_cron(){
  ensure_certbot
  cat >"$CRONFILE" <<CRON
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
10 3 * * * root certbot renew --quiet \
--pre-hook "docker stop dujiao-gw >/dev/null 2>&1 || true" \
--post-hook "docker start dujiao-gw >/dev/null 2>&1 || true"
CRON
  chmod 644 "$CRONFILE"
  systemctl restart cron 2>/dev/null || true
  echo -e "${GREEN}✅ 续签任务已写入${RESET}"
}

redis_alias_fix(){
  docker network disconnect "$NET" dujiao-next-redis-1 >/dev/null 2>&1 || true
  docker network connect --alias redis "$NET" dujiao-next-redis-1 >/dev/null 2>&1 || true
  docker restart dujiao-next-api-1 >/dev/null 2>&1 || true
  echo -e "${GREEN}✅ Redis alias已修复${RESET}"
}

while true; do
  echo ""
  echo "1) 稳定增强版"
  echo "2) 迁移/测试模式"
  echo "3) 安全模式"
  echo "0) 退出"
  read -p "请选择: " MODE
  case "$MODE" in
    1|2|3) break ;;
    0) exit 0 ;;
    *) echo "无效输入";;
  esac
done

while true; do
  echo ""
  echo "1) 使用原始URL"
  echo "2) 自动使用公网IP"
  echo "3) 手动输入URL"
  echo "4) 不修改URL"
  echo "0) 返回上一级"
  read -p "请选择: " URL_MODE
  case "$URL_MODE" in
    1|2|3|4) break ;;
    0) exec "$0" ;;
    *) echo "无效输入";;
  esac
done

NEW_URL=""
if [[ "$URL_MODE" == "2" ]]; then
  IP=$(detect_public_ip)
  NEW_URL="http://${IP}:8082"
elif [[ "$URL_MODE" == "3" ]]; then
  read -p "输入URL: " NEW_URL
fi

echo -e "${BLUE}== 开始恢复 ==${RESET}"

BACKUP=$(ls -t /root/dujiao_full_backup_*.tar.gz 2>/dev/null | head -n1)
[[ -f "$BACKUP" ]] || { echo -e "${RED}未找到备份文件${RESET}"; exit 1; }

safe_rm dujiao-gw
safe_rm tokenpay
safe_rm dujiao-next-admin-1
safe_rm dujiao-next-user-1
safe_rm dujiao-next-api-1
safe_rm dujiao-next-redis-1

tar -xzf "$BACKUP" -C /

if [[ -n "$NEW_URL" && -f "$CFG" ]]; then
  sed -i -E "s|^[[:space:]]*url:[[:space:]]*.*$|url: ${NEW_URL}|" "$CFG"
fi

docker pull nginx:alpine >/dev/null
docker pull redis:7-alpine >/dev/null
docker pull dujiaonext/api:latest >/dev/null
docker pull dujiaonext/user:latest >/dev/null
docker pull dujiaonext/admin:latest >/dev/null
docker pull dapiaoliang666/tokenpay:latest >/dev/null

ensure_network
port_check

docker run -d --name dujiao-next-redis-1 --network "$NET" --network-alias redis -v /opt/dujiao-next/data/redis:/data redis:7-alpine >/dev/null
docker run -d --name dujiao-next-api-1 --network "$NET" -p 8080:8080 \
  -v /opt/dujiao-next/data/logs:/app/logs \
  -v /opt/dujiao-next/config/config.yml:/app/config.yml:ro \
  -v /opt/dujiao-next/data/db:/app/db \
  -v /opt/dujiao-next/data/uploads:/app/uploads \
  dujiaonext/api:latest >/dev/null

docker run -d --name dujiao-next-user-1 --network "$NET" -p 8081:80 dujiaonext/user:latest >/dev/null
docker run -d --name dujiao-next-admin-1 --network "$NET" -p 8082:80 dujiaonext/admin:latest >/dev/null
docker run -d --name tokenpay --network "$NET" -p 52939:8080 \
  -v /opt/tokenpay:/data \
  -v /opt/tokenpay/appsettings.json:/app/appsettings.json \
  dapiaoliang666/tokenpay:latest >/dev/null

redis_alias_fix

if [[ "$MODE" == "1" ]]; then
  ensure_certificate
  ensure_cron
  docker run -d --name dujiao-gw --network "$NET" -p 80:80 -p 443:443 \
    -v /opt/dujiao-gw/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
    -v /etc/letsencrypt:/etc/letsencrypt:ro nginx:alpine >/dev/null
fi

echo -e "${GREEN}恢复完成${RESET}"
docker ps

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo -e "${BLUE}总耗时: ${ELAPSED} 秒${RESET}"
