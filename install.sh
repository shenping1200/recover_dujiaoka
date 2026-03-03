#!/usr/bin/env bash
set -euo pipefail

echo "===================================="
echo " Dujiao Auto Install"
echo "===================================="

cd /root

echo "⬇ 下载备份文件..."
curl -L -o dujiao_full_backup_2026-03-03_064139.tar.gz \
https://raw.githubusercontent.com/shenping1200/recover_dujiaoka/main/dujiao_full_backup_2026-03-03_064139.tar.gz

echo "⬇ 下载恢复脚本..."
curl -L -o restore_dujiao_universal.sh \
https://raw.githubusercontent.com/shenping1200/recover_dujiaoka/main/restore_dujiao_universal.sh

chmod +x restore_dujiao_universal.sh

echo "🚀 开始执行恢复脚本..."
bash restore_dujiao_universal.sh
