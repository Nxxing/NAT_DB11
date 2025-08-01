# Debian 11 端口轉發工具 (nftables)

🚀 **一鍵設置 Debian 11 端口轉發的專業工具**

專為 Debian 11 (Bullseye) 設計的 nftables 端口轉發腳本，支持自動 IP 轉發配置、域名解析和持久化配置。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Debian](https://img.shields.io/badge/Debian-11-red.svg)](https://www.debian.org/)
[![nftables](https://img.shields.io/badge/nftables-supported-green.svg)](https://wiki.nftables.org/)

## ✨ 特色功能

- 🎯 **一鍵安裝** - 從 SSH 直接執行，無需下載
- 🔄 **自動 IP 轉發** - 自動檢測並啟用 IPv4 轉發功能
- 🌐 **智能域名解析** - 支持域名和 IP 地址，自動解析為 IP
- 🔧 **網卡自動檢測** - 自動檢測網絡接口，無需手動指定
- 📦 **完整測試驗證** - 內建連通性測試和配置驗證
- 💾 **永久化配置** - 重啟後自動恢復端口轉發規則
- 🛠️ **管理工具** - 提供便捷的管理和監控命令
- 🔒 **安全可靠** - 使用現代 nftables 替代傳統 iptables

## 🚀 快速開始

### 一鍵安裝（推薦）

```bash
# 基本用法 - 轉發端口範圍
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- nx05.servegame.com 38054 38303

# 指定網絡接口
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- nx05.servegame.com 38054 38303 eth0

# 使用 IP 地址
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- 192.168.1.100 8080 8090
```

### 手動安裝

```bash
# 克隆倉庫
git clone https://github.com/Nxxing/NAT_DB11.git
cd NAT_DB11

# 執行腳本
chmod +x port-forward.sh
sudo ./port-forward.sh nx05.servegame.com 38054 38303
```

## 📖 使用方法

### 基本語法

```bash
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- <目標服務器> <起始端口> <結束端口> [網絡接口]
```

### 參數說明

| 參數 | 說明 | 必需 | 示例 |
|------|------|------|------|
| `目標服務器` | 目標服務器的 IP 地址或域名 | ✅ | `nx05.servegame.com` |
| `起始端口` | 轉發端口範圍的起始端口 (1-65535) | ✅ | `38054` |
| `結束端口` | 轉發端口範圍的結束端口 (1-65535) | ✅ | `38303` |
| `網絡接口` | 指定網絡接口名稱 | ❌ | `eth0`, `ens3` |

## 🎮 使用場景示例

### 遊戲服務器

```bash
# Minecraft 服務器
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- mc.example.com 25565 25565

# 多人遊戲服務器 (端口範圍)
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- game.server.com 7777 7800

# Steam 遊戲服務器
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- steam.example.com 27015 27030
```

### Web 應用服務

```bash
# HTTP/HTTPS 服務
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- web.example.com 80 443

# 微服務集群
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- api.example.com 8000 8010

# 開發環境
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- dev.local 3000 3005
```

### 數據庫和中間件

```bash
# PostgreSQL 集群
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- db.example.com 5432 5439

# Redis 集群
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- redis.example.com 6379 6389

# MongoDB 副本集
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- mongo.example.com 27017 27019
```

## 🛠️ 管理命令

安裝完成後，可以使用以下管理命令：

```bash
# 查看狀態
port-forward-manager status

# 重啟服務
port-forward-manager restart

# 查看轉發規則  
port-forward-manager rules

# 停止轉發
port-forward-manager stop

# 重新載入配置
port-forward-manager reload
```

### 狀態檢查示例

```bash
$ port-forward-manager status
=== Port Forwarding Status ===
nftables service: Active
Rules table: Loaded  
NAT rules: 500
IP forwarding: Enabled
```

## 🧪 測試和驗證

### 手動測試端口

```bash
# 測試單個端口
telnet YOUR_SERVER_IP 38054

# 測試端口範圍（需要 nc 工具）
nc -zv YOUR_SERVER_IP 38054-38060

# 使用 nmap 掃描端口
nmap -p 38054-38060 YOUR_SERVER_IP
```

### 檢查配置

```bash
# 查看 nftables 規則
sudo nft list ruleset

# 查看端口轉發表
sudo nft list table inet port_forward

# 檢查 IP 轉發狀態
cat /proc/sys/net/ipv4/ip_forward

# 查看網絡連接
ss -tuln | grep -E ":(38054|38055|38056)"
```

## 📋 系統要求

| 項目 | 要求 | 說明 |
|------|------|------|
| **作業系統** | Debian 11 (Bullseye) | 主要測試環境 |
| **權限** | root 或 sudo | 需要管理員權限 |
| **網絡** | 互聯網連接 | 用於安裝套件和DNS解析 |
| **記憶體** | 512MB+ | 建議最低配置 |

### 相容性說明

- ✅ **完全支持**: Debian 11 (Bullseye)
- ⚠️ **部分支持**: Ubuntu 20.04+, Debian 10 (可能需要調整)
- ❌ **不支持**: CentOS, RHEL, OpenWRT

## 🔧 工作原理

### 1. 系統檢查和準備
- 檢查 root 權限
- 驗證參數有效性
- 安裝 nftables (如果需要)

### 2. 網路配置
- 解析域名為 IP 地址
- 自動檢測網絡接口
- 啟用 IPv4 轉發

### 3. 防火牆規則配置
- 清理舊的轉發規則
- 創建 nftables 規則表
- 配置 DNAT 和 MASQUERADE 規則

### 4. 持久化和驗證
- 保存配置文件
- 設置開機自啟
- 驗證配置正確性

### nftables 規則結構

```
table inet port_forward {
    chain prerouting {
        # DNAT 規則 - 將入站流量轉發到目標服務器
        iifname "eth0" ip protocol tcp tcp dport 38054 dnat to 192.168.1.100:38054
    }
    
    chain postrouting {
        # MASQUERADE 規則 - 修改源地址確保回程流量正確
        ip daddr 192.168.1.100 ip protocol tcp tcp dport 38054 masquerade
    }
    
    chain input/forward {
        # ACCEPT 規則 - 允許相關流量通過
        ip protocol tcp tcp dport 38054 accept
    }
}
```

## 📁 文件結構

```
/etc/
├── nftables.conf                    # nftables 主配置文件
└── nftables.d/
    └── port_forward.nft             # 端口轉發規則文件

/usr/local/bin/
└── port-forward-manager             # 管理工具

/etc/sysctl.conf                     # IP 轉發配置
```

## 🐛 故障排除

### 常見問題

#### 1. "Permission denied" 錯誤
**原因**: 沒有使用 sudo 執行
**解決**: 在命令前加上 `sudo`

#### 2. "Command not found" 錯誤  
**原因**: 系統缺少 curl 工具
**解決**: 
```bash
sudo apt update && sudo apt install curl
```

#### 3. "Connection refused" 錯誤
**原因**: 雲服務商安全組未開放端口
**解決**: 
- 檢查阿里雲/AWS/Azure 安全組設置
- 確保入站規則開放了相應端口

#### 4. "DNS resolution failed" 錯誤
**原因**: 域名無法解析或網絡問題
**解決**:
```bash
# 檢查 DNS 配置
cat /etc/resolv.conf

# 測試域名解析
nslookup nx05.servegame.com

# 使用 IP 地址替代域名
curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- 192.168.1.100 38054 38303
```

### 詳細診斷

```bash
# 檢查系統狀態
systemctl status nftables

# 查看詳細錯誤日誌  
journalctl -u nftables -f

# 檢查網絡配置
ip route show
ip addr show

# 測試網絡連通性
ping 8.8.8.8
ping 目標服務器IP
```

### 恢復和重置

```bash
# 完全重置 nftables 規則
sudo nft flush ruleset

# 停止並重新配置
sudo port-forward-manager stop
# 重新執行安裝命令

# 恢復備份配置
sudo cp /etc/sysctl.conf.backup.* /etc/sysctl.conf
```

## 🔒 安全考慮

### 重要提醒

⚠️ **防火牆設置**: 確保雲服務商的安全組已正確配置開放端口
⚠️ **目標服務器**: 驗證目標服務器確實在監聽指定端口
⚠️ **網絡安全**: 對於敏感服務建議使用 VPN 或 IP 白名單
⚠️ **監控告警**: 定期檢查日誌是否有異常流量模式

### 安全最佳實踐

1. **最小權限原則** - 只開放必要的端口
2. **定期審查** - 定期檢查轉發規則是否仍然需要
3. **監控日誌** - 監控異常連接和流量
4. **備份配置** - 定期備份重要配置文件

## 📊 性能和限制

### 性能特點

- **延遲增加**: 通常增加 1-5ms 延遲
- **吞吐量**: 理論上不限制，實際受服務器網絡帶寬限制
- **並發連接**: 支持數千個並發連接
- **資源消耗**: CPU 和內存消耗極低 (<1%)

### 使用限制

- **端口數量**: 理論上支持 65535 個端口，建議單次配置不超過 1000 個
- **協議支持**: 支持 TCP 和 UDP，不支持 ICMP
- **IPv6**: 當前版本主要支持 IPv4

## 🤝 貢獻指南

歡迎參與項目改進！

### 報告問題

1. 在 [Issues](https://github.com/Nxxing/NAT_DB11/issues) 頁面創建新問題
2. 請包含以下信息：
   - 作業系統版本
   - 完整的錯誤信息
   - 執行的具體命令
   - 預期行為和實際行為

### 提交改進

1. Fork 本倉庫
2. 創建功能分支: `git checkout -b feature/amazing-feature`
3. 提交更改: `git commit -m 'Add amazing feature'`
4. 推送分支: `git push origin feature/amazing-feature`
5. 創建 Pull Request

### 開發環境

```bash
# 克隆倉庫
git clone https://github.com/Nxxing/NAT_DB11.git
cd NAT_DB11

# 創建測試環境
vagrant up  # 如果使用 Vagrant

# 運行測試
./test/run_tests.sh
```

## 📚 相關資源

### 官方文檔
- [nftables Wiki](https://wiki.nftables.org/)
- [Debian 11 發行說明](https://www.debian.org/releases/bullseye/)
- [Linux 網絡管理](https://www.kernel.org/doc/Documentation/networking/)

### 教程和指南
- [nftables vs iptables](https://wiki.archlinux.org/title/Nftables)
- [Debian 網絡配置](https://wiki.debian.org/NetworkConfiguration)
- [端口轉發最佳實踐](https://www.digitalocean.com/community/tutorials)

## 📄 許可證

本項目使用 [MIT 許可證](LICENSE)。

```
MIT License

Copyright (c) 2024 NAT_DB11

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🏆 致謝

- 感謝 [nftables](https://netfilter.org/projects/nftables/) 項目提供現代化的防火牆框架
- 感謝 [Debian](https://www.debian.org/) 社區的穩定系統支持
- 感謝所有貢獻者和使用者的回饋和建議

## 📞 聯繫方式

- **GitHub Issues**: [提交問題](https://github.com/Nxxing/NAT_DB11/issues)
- **GitHub Discussions**: [討論區](https://github.com/Nxxing/NAT_DB11/discussions)
- **Email**: [聯繫維護者](mailto:your-email@example.com)

---

⭐ **如果這個項目對您有幫助，請給我們一個 Star！**

![GitHub stars](https://img.shields.io/github/stars/Nxxing/NAT_DB11?style=social)
![GitHub forks](https://img.shields.io/github/forks/Nxxing/NAT_DB11?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/Nxxing/NAT_DB11?style=social)
