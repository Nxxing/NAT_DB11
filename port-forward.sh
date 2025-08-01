# 設置參數並解析域名
DEST_IP="nx0game.com"
PORT_START=38
PORT_END=303
LOCAL_IFACE="eth0"

echo "========== IP 轉發檢查和配置 =========="

# 檢查當前 IP 轉發狀態
CURRENT_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
echo "當前 IP 轉發狀態: $CURRENT_FORWARD"

if [[ "$CURRENT_FORWARD" == "1" ]]; then
    echo "✓ IP 轉發已啟用"
else
    echo "⚠ IP 轉發未啟用，正在開啟..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # 驗證是否成功啟用
    if [[ $(cat /proc/sys/net/ipv4/ip_forward) == "1" ]]; then
        echo "✓ IP 轉發已臨時啟用"
    else
        echo "✗ 無法啟用 IP 轉發"
        exit 1
    fi
fi

# 檢查永久配置
echo "檢查永久 IP 轉發配置..."
if grep -q "^net.ipv4.ip_forward.*=.*1" /etc/sysctl.conf; then
    echo "✓ IP 轉發已永久啟用"
else
    echo "⚠ IP 轉發未永久啟用，正在修復..."
    
    # 備份 sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
        # 更新現有行
        sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
        echo "✓ 已更新 sysctl.conf 中的 IP 轉發設置"
    else
        # 添加新行
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        echo "✓ 已在 sysctl.conf 中添加 IP 轉發設置"
    fi
    
    # 應用更改
    sysctl -p >/dev/null 2>&1 && echo "✓ 已應用 sysctl 更改" || echo "⚠ sysctl 應用失敗，但 IP 轉發仍已啟用"
fi

# 檢查 IPv6 轉發（可選）
if [[ -f /proc/sys/net/ipv6/conf/all/forwarding ]]; then
    IPV6_FORWARD=$(cat /proc/sys/net/ipv6/conf/all/forwarding)
    if [[ "$IPV6_FORWARD" == "1" ]]; then
        echo "✓ IPv6 轉發已啟用"
    else
        echo "啟用 IPv6 轉發以獲得更好的兼容性..."
        echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
        if ! grep -q "^net.ipv6.conf.all.forwarding" /etc/sysctl.conf; then
            echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
        fi
        echo "✓ IPv6 轉發已啟用"
    fi
fi

echo ""
echo "========== 域名解析和端口轉發配置 =========="

# 解析域名為 IP 地址
echo "解析域名 $DEST_IP..."
RESOLVED_IP=$(nslookup $DEST_IP 2>/dev/null | awk '/^Address: / { print $2 }' | tail -1)
if [[ -z "$RESOLVED_IP" || ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "嘗試使用 getent 解析..."
    RESOLVED_IP=$(getent hosts $DEST_IP 2>/dev/null | awk '{print $1}' | head -1)
fi

if [[ -z "$RESOLVED_IP" || ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "✗ 無法解析域名 $DEST_IP"
    echo "請檢查："
    echo "1. 域名是否正確"
    echo "2. DNS 配置是否正常"
    echo "3. 網絡連接是否正常"
    exit 1
fi

echo "✓ 域名 $DEST_IP 解析為 IP: $RESOLVED_IP"

# 檢測網卡
if ! ip link show $LOCAL_IFACE &> /dev/null; then
    echo "網卡 $LOCAL_IFACE 不存在，自動檢測..."
    LOCAL_IFACE=$(ip route | grep default | head -1 | awk '{print $5}')
    echo "使用網卡: $LOCAL_IFACE"
fi

# 測試目標服務器連通性
echo "測試目標服務器連通性..."
if ping -c 1 -W 3 $RESOLVED_IP >/dev/null 2>&1; then
    echo "✓ 目標服務器 $RESOLVED_IP 可達"
    RTT=$(ping -c 1 -W 3 $RESOLVED_IP 2>/dev/null | grep "time=" | sed 's/.*time=\([0-9.]*\).*/\1/')
    [[ -n "$RTT" ]] && echo "  延遲: ${RTT}ms"
else
    echo "⚠ 目標服務器 $RESOLVED_IP 無法 ping 通，但繼續配置轉發規則"
fi

# 啟動 nftables 服務
echo ""
echo "檢查和啟動 nftables 服務..."
if ! systemctl is-active --quiet nftables; then
    echo "啟動 nftables 服務..."
    systemctl enable nftables >/dev/null 2>&1
    systemctl start nftables >/dev/null 2>&1
    sleep 2
fi

if systemctl is-active --quiet nftables; then
    echo "✓ nftables 服務運行正常"
else
    echo "✗ nftables 服務啟動失敗"
    systemctl status nftables
    exit 1
fi

# 清理並重新創建規則
echo ""
echo "配置端口轉發規則..."
nft delete table inet port_forward 2>/dev/null || true

# 創建表和鏈
nft add table inet port_forward
nft add chain inet port_forward prerouting { type nat hook prerouting priority 100 \; }
nft add chain inet port_forward postrouting { type nat hook postrouting priority 100 \; }
nft add chain inet port_forward input { type filter hook input priority 0 \; policy accept \; }
nft add chain inet port_forward forward { type filter hook forward priority 0 \; policy accept \; }

# 添加基本規則
nft add rule inet port_forward input ct state related,established accept
nft add rule inet port_forward forward ct state related,established accept

# 批量添加端口轉發規則
echo "添加端口 $PORT_START-$PORT_END 的轉發規則..."
RULE_COUNT=0
TOTAL_PORTS=$(($PORT_END - $PORT_START + 1))

for port in $(seq $PORT_START $PORT_END); do
    # DNAT 規則 - 必須指定 ip protocol
    nft add rule inet port_forward prerouting iifname "$LOCAL_IFACE" ip protocol tcp tcp dport $port dnat to $RESOLVED_IP:$port
    nft add rule inet port_forward prerouting iifname "$LOCAL_IFACE" ip protocol udp udp dport $port dnat to $RESOLVED_IP:$port
    
    # MASQUERADE 規則
    nft add rule inet port_forward postrouting ip daddr $RESOLVED_IP ip protocol tcp tcp dport $port masquerade
    nft add rule inet port_forward postrouting ip daddr $RESOLVED_IP ip protocol udp udp dport $port masquerade
    
    # ACCEPT 規則
    nft add rule inet port_forward input ip protocol tcp tcp dport $port accept
    nft add rule inet port_forward input ip protocol udp udp dport $port accept
    nft add rule inet port_forward forward ip protocol tcp tcp dport $port accept
    nft add rule inet port_forward forward ip protocol udp udp dport $port accept
    
    RULE_COUNT=$(($RULE_COUNT + 1))
    
    # 每50個端口顯示進度
    if [ $(($RULE_COUNT % 50)) -eq 0 ] || [ $RULE_COUNT -eq $TOTAL_PORTS ]; then
        echo "進度: $RULE_COUNT/$TOTAL_PORTS 端口已配置"
    fi
done

echo ""
echo "========== 配置完成驗證 =========="

# 最終驗證
echo "最終系統狀態檢查："

# IP 轉發狀態
FINAL_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ "$FINAL_FORWARD" == "1" ]]; then
    echo "✓ IP 轉發: 已啟用"
else
    echo "✗ IP 轉發: 未啟用"
fi

# nftables 服務
if systemctl is-active --quiet nftables; then
    echo "✓ nftables 服務: 運行中"
else
    echo "✗ nftables 服務: 未運行"
fi

# 轉發表
if nft list tables | grep -q "inet port_forward"; then
    echo "✓ port_forward 表: 已創建"
    NAT_RULES=$(nft list table inet port_forward | grep -c "dnat\|masquerade")
    echo "✓ NAT 規則數量: $NAT_RULES"
else
    echo "✗ port_forward 表: 創建失敗"
fi

echo ""
echo "========== 配置摘要 =========="
echo "✓ 域名: $DEST_IP"
echo "✓ 解析IP: $RESOLVED_IP"
echo "✓ 網卡: $LOCAL_IFACE"
echo "✓ 端口範圍: $PORT_START-$PORT_END (TCP/UDP)"
echo "✓ 總端口數: $TOTAL_PORTS"
echo "✓ IP轉發: 已啟用並永久配置"
echo ""
echo "測試命令："
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "telnet $LOCAL_IP $PORT_START"
echo "nc -zv $LOCAL_IP $PORT_START-$(($PORT_START + 4))"
echo ""
echo "========== 配置完成 =========="
