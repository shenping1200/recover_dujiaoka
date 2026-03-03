#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# 复制备份到 /root
cp -f ./dujiao_full_backup_*.tar.gz /root/

# 复制恢复脚本到 /root
cp -f ./restore_dujiao_universal.sh /root/restore_dujiao_universal.sh
chmod +x /root/restore_dujiao_universal.sh

echo "✅ 已准备完成："
echo "1) 备份 -> /root/dujiao_full_backup_*.tar.gz"
echo "2) 脚本 -> /root/restore_dujiao_universal.sh"
echo ""
echo "下一步执行："
echo "/root/restore_dujiao_universal.sh"
