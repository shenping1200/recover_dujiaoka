#!/usr/bin/env bash
set -euo pipefail

echo "===================================="
echo "   Dujiao Universal Auto Install    "
echo "===================================="

cd /root

# 1. 下载全量备份文件 (建议上传至 GitHub 时去掉日期后缀)
echo "📥 下载备份文件数据包..."
curl -L -o dujiao_full_backup.tar.gz \
https://raw.githubusercontent.com/shenping1200/recover_dujiaoka/main/dujiao_full_backup.tar.gz

# 2. 下载 Docker 镜像包 (这是解决本地镜像缺失的关键)
echo "📥 下载 Docker 镜像全量包 (235MB)..."
curl -L -o all_images.tar \
https://raw.githubusercontent.com/shenping1200/recover_dujiaoka/main/all_images.tar

# 3. 下载优化后的恢复脚本
echo "📥 下载恢复脚本逻辑..."
curl -L -o restore_dujiao_universal.sh \
https://raw.githubusercontent.com/shenping1200/recover_dujiaoka/main/restore_dujiao_universal.sh

chmod +x restore_dujiao_universal.sh

echo "🚀 开始执行全自动恢复任务..."
bash restore_dujiao_universal.sh
