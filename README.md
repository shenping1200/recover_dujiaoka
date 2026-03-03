# recover_dujiaoka

用于迁移 / 恢复 Dujiao-Next + TokenPay + 网关 + 证书 + 续签

---

## ⚠ 部署前必须做的事情

1️⃣ 先把域名解析到当前 VPS IP

A 记录：

yufu120.de5.net  →  VPS_IP  
pay.yufu120.de5.net  →  VPS_IP  

（建议灰云，仅 DNS）

---

## 🚀 一键部署命令

在新 VPS 上执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/shenping1200/recover_dujiaoka/main/install.sh)
