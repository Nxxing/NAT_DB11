# 設置參數
DEST_IP="nx05.servegame.com"
PORT_START=38054
PORT_END=38303

echo "========== 修復端口轉發配置 =========="

# 檢查 root 權限
if [[ $EUID -ne 0 ]]; then
    echo "錯誤：需要 root 權限"
    exit 1
fi

# 解析域名
echo "解析域名 $DEST_IP..."
RESOLVED_IP=$(nslookup $DEST_IP 2>/dev/null | awk '/^Address: / { print $2 }' | tail -1)
if [[ -z "$RESOLVED_IP" || ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    RESOLVED_IP=$(getent hosts $DEST_IP 2>/dev/null | awk '{print $1}' | head -1)
fi

if [[ -z "$RESOLVED_IP" || ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "✗ 無法解析域名 $DEST_IP，請手動輸入 IP"
    read -p "輸入目標服務器 IP: " RESOLVED_IP
    if [[ ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "✗ IP 格式不正確"
        exit 1
    fi
fi

echo "✓ 解析結果: $DEST_IP → $RESOLVED_IP"

# 檢測網卡（避免日誌混入）
LOCAL_IFACE=$(ip route | grep default | head -1 | awk '{print $5}')
if [[ -z "$LOCAL_IFACE" ]]; then
    LOCAL_IFACE="eth0"
fi
echo "✓ 使用網卡: $LOCAL_IFACE"

# 啟用 IP 轉發
echo "檢查 IP 轉發..."
if [[ $(cat /proc/sys/net/ipv4/ip_forward) != "1" ]]; then
    echo 1 > /proc/sys/net/ipv4/ip_forward
    if ! grep -q "^net.ipv4.ip_forward.*=.*1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi
    echo "✓ IP 轉發已啟用"
else
    echo "✓ IP 轉發已經啟用"
fi

# 啟動 nftables
echo "啟動 nftables 服務..."
systemctl enable nftables >/dev/null 2>&1
systemctl start nftables >/dev/null 2>&1
sleep 1

if systemctl is-active --quiet nftables; then
    echo "✓ nftables 服務運行正常"
else
    echo "✗ nftables 服務啟動失敗"
    exit 1
fi

# 清理舊規則
echo "清理舊規則..."
nft delete table inet port_forward 2>/dev/null || true

# 創建新的表和鏈（避免語法錯誤）
echo "創建 nftables 規則..."
nft add table inet port_forward
nft add chain inet port_forward prerouting '{ type nat hook prerouting priority 100; }'
nft add chain inet port_forward postrouting '{ type nat hook postrouting priority 100; }'
nft add chain inet port_forward input '{ type filter hook input priority 0; policy accept; }'
nft add chain inet port_forward forward '{ type filter hook forward priority 0; policy accept; }'

# 添加基本規則
nft add rule inet port_forward input ct state related,established accept
nft add rule inet port_forward forward ct state related,established accept

# 批量添加端口轉發規則（修正語法）
echo "添加端口 $PORT_START-$PORT_END 的轉發規則..."
TOTAL_PORTS=$((PORT_END - PORT_START + 1))
PROCESSED=0

for port in $(seq $PORT_START $PORT_END); do
    # DNAT 規則 (TCP/UDP) - 使用正確語法
    nft add rule inet port_forward prerouting iifname "$LOCAL_IFACE" ip protocol tcp tcp dport $port dnat to "$RESOLVED_IP:$port"
    nft add rule inet port_forward prerouting iifname "$LOCAL_IFACE" ip protocol udp udp dport $port dnat to "$RESOLVED_IP:$port"
    
    # MASQUERADE 規則 (TCP/UDP)
    nft add rule inet port_forward postrouting ip daddr "$RESOLVED_IP" ip protocol tcp tcp dport $port masquerade
    nft add rule inet port_forward postrouting ip daddr "$RESOLVED_IP" ip protocol udp udp dport $port masquerade
    
    # ACCEPT 規則 (TCP/UDP)
    nft add rule inet port_forward input ip protocol tcp tcp dport $port accept
    nft add rule inet port_forward input ip protocol udp udp dport $port accept
    nft add rule inet port_forward forward ip protocol tcp tcp dport $port accept
    nft add rule inet port_forward forward ip protocol udp udp dport $port accept
    
    PROCESSED=$((PROCESSED + 1))
    
    # 每 50 個端口顯示進度
    if [ $((PROCESSED % 50)) -eq 0 ] || [ $PROCESSED -eq $TOTAL_PORTS ]; then
        echo "進度: $PROCESSED/$TOTAL_PORTS 端口"
    fi
done

# 保存配置
echo "保存配置..."
mkdir -p /etc/nftables.d

cat > /etc/nftables.d/port_forward.nft << EOF
#!/usr/sbin/nft -f
# Port forwarding rules for $DEST_IP ($RESOLVED_IP)
# Ports: $PORT_START-$PORT_END
# Generated: $(date)

table inet port_forward {
    chain prerouting {
        type nat hook prerouting priority 100; policy accept;
$(for port in $(seq $PORT_START $PORT_END); do
    echo "        iifname \"$LOCAL_IFACE\" ip protocol tcp tcp dport $port dnat to $RESOLVED_IP:$port"
    echo "        iifname \"$LOCAL_IFACE\" ip protocol udp udp dport $port dnat to $RESOLVED_IP:$port"
done)
    }

    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
$(for port in $(seq $PORT_START $PORT_END); do
    echo "        ip daddr $RESOLVED_IP ip protocol tcp tcp dport $port masquerade"
    echo "        ip daddr $RESOLVED_IP ip protocol udp udp dport $port masquerade"
done)
    }

    chain input {
        type filter hook input priority 0; policy accept;
        ct state related,established accept
$(for port in $(seq $PORT_START $PORT_END); do
    echo "        ip protocol tcp tcp dport $port accept"
    echo "        ip protocol udp udp dport $port accept"
done)
    }

    chain forward {
        type filter hook forward priority 0; policy accept;
        ct state related,established accept
$(for port in $(seq $PORT_START $PORT_END); do
    echo "        ip protocol tcp tcp dport $port accept"
    echo "        ip protocol udp udp dport $port accept"
done)
    }
}
EOF

# 添加到主配置
if ! grep -q "/etc/nftables.d/port_forward.nft" /etc/nftables.conf 2>/dev/null; then
    echo 'include "/etc/nftables.d/port_forward.nft"' >> /etc/nftables.conf
fi

echo "✓ 配置已保存"

# 最終驗證
echo ""
echo "========== 最終驗證 =========="

if systemctl is-active --quiet nftables; then
    echo "✓ nftables 服務: 運行中"
else
    echo "✗ nftables 服務: 異常"
fi

if nft list tables | grep -q "inet port_forward"; then
    NAT_RULES=$(nft list table inet port_forward | grep -c "dnat\|masquerade")
    echo "✓ port_forward 表: 已創建"
    echo "✓ NAT 規則數量: $NAT_RULES"
else
    echo "✗ port_forward 表: 不存在"
fi

if [[ $(cat /proc/sys/net/ipv4/ip_forward) == "1" ]]; then
    echo "✓ IP 轉發: 已啟用"
else
    echo "✗ IP 轉發: 未啟用"
fi

echo ""
echo "========== 配置摘要 =========="
echo "✓ 目標服務器: $DEST_IP"
echo "✓ 解析 IP: $RESOLVED_IP"
echo "✓ 網卡: $LOCAL_IFACE"
echo "✓ 端口範圍: $PORT_START-$PORT_END"
echo "✓ 總端口數: $TOTAL_PORTS"
echo "✓ 本機 IP: $(hostname -I | awk '{print $1}')"

echo ""
echo "測試命令:"
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "telnet $LOCAL_IP $PORT_START"
echo "nc -zv $LOCAL_IP $PORT_START-$((PORT_START + 4))"

echo ""
echo "========== 配置完成 =========="
