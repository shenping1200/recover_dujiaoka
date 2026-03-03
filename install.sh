cat >install.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# 1) 把备份包复制到 /root（恢复脚本会从 /root 读取最新备份）
cp -f ./dujiao_full_backup_*.tar.gz /root/

# 2) 把恢复脚本放到 /root
cp -f ./restore_dujiao_universal.sh /root/restore_dujiao_universal.sh
chmod +x /root/restore_dujiao_universal.sh

echo "✅ 已准备完成："
echo "1) 备份包 -> /root/dujiao_full_backup_*.tar.gz"
echo "2) 脚本   -> /root/restore_dujiao_universal.sh"
echo ""
echo "下一步运行："
echo "  /root/restore_dujiao_universal.sh"
EOF

chmod +x install.sh
