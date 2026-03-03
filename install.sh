#!/usr/bin/env bash
set -euo pipefail

echo "⬇ 下载备份文件..."
curl -L -o /root/dujiao_full_backup.tar.gz \
https://raw.githubusercontent.com/shenping1200/recover_dujiaoka/main/dujiao_full_backup_2026-03-03_064139.tar.gz

echo "⬇ 下载恢复脚本..."
curl -L -o /root/restore_dujiao_universal.sh \
https://raw.githubusercontent.com/shenping1200/recover_dujiaoka/main/restore_dujiao_universal.sh

chmod +x /root/restore_dujiao_universal.sh

echo "🚀 开始恢复..."
/root/restore_dujiao_universal.sh
