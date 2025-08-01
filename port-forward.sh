#!/bin/bash

# Debian 11 Port Forward Script - Completely Fixed Version
# Usage: curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- <dest_ip> <port_start> <port_end> [interface]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Show usage
show_usage() {
    echo "Debian 11 Port Forward Script"
    echo ""
    echo "Usage: curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- <dest_ip> <port_start> <port_end> [interface]"
    echo ""
    echo "Examples:"
    echo "  curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- nx05.servegame.com 38054 38303"
    echo "  curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- 192.168.1.100 29287 29291 eth0"
}

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (use sudo)"
    exit 1
fi

# Handle help or no parameters
if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" || $# -eq 0 ]]; then
    show_usage
    exit 0
fi

# Validate parameters
if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo -e "${RED}[ERROR]${NC} Invalid number of parameters"
    show_usage
    exit 1
fi

if [[ -z "$1" ]]; then
    echo -e "${RED}[ERROR]${NC} Destination IP/hostname cannot be empty"
    exit 1
fi

if ! [[ "$2" =~ ^[0-9]+$ ]] || ! [[ "$3" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}[ERROR]${NC} Port numbers must be integers"
    exit 1
fi

if [[ $2 -lt 1 || $2 -gt 65535 || $3 -lt 1 || $3 -gt 65535 ]]; then
    echo -e "${RED}[ERROR]${NC} Port numbers must be between 1 and 65535"
    exit 1
fi

if [[ $2 -gt $3 ]]; then
    echo -e "${RED}[ERROR]${NC} Start port ($2) cannot be greater than end port ($3)"
    exit 1
fi

if [[ -n "$4" ]] && ! ip link show "$4" &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Network interface '$4' does not exist"
    exit 1
fi

# Parse parameters
DEST_HOSTNAME="$1"
PORT_START="$2"
PORT_END="$3"
USER_INTERFACE="$4"

echo -e "${BLUE}========================================="
echo "    Debian 11 Port Forwarding Setup"
echo -e "=========================================${NC}"
echo ""
echo "Parameters:"
echo "  Destination:   $DEST_HOSTNAME"
echo "  Port Range:    $PORT_START-$PORT_END"
echo "  Interface:     ${USER_INTERFACE:-auto-detect}"
echo "  Total Ports:   $((PORT_END - PORT_START + 1))"
echo ""

# Resolve hostname to IP - NO FUNCTIONS, direct code
echo -e "${GREEN}[INFO]${NC} Resolving hostname: $DEST_HOSTNAME"

RESOLVED_IP=""

# Check if it's already an IP address
if [[ "$DEST_HOSTNAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    RESOLVED_IP="$DEST_HOSTNAME"
else
    # Try nslookup
    RESOLVED_IP=$(nslookup "$DEST_HOSTNAME" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -1)
    
    # Try getent if nslookup failed
    if [[ -z "$RESOLVED_IP" || ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        RESOLVED_IP=$(getent hosts "$DEST_HOSTNAME" 2>/dev/null | awk '{print $1}' | head -1)
    fi
    
    # Try dig if getent failed
    if [[ -z "$RESOLVED_IP" || ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if command -v dig &> /dev/null; then
            RESOLVED_IP=$(dig +short "$DEST_HOSTNAME" 2>/dev/null | head -1)
        fi
    fi
fi

# Check if resolution was successful
if [[ -z "$RESOLVED_IP" || ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}[ERROR]${NC} Failed to resolve hostname: $DEST_HOSTNAME"
    echo ""
    echo "Troubleshooting DNS resolution:"
    echo "1. Check if hostname is correct: $DEST_HOSTNAME"
    echo "2. Test DNS: nslookup $DEST_HOSTNAME"
    echo "3. Check network: ping 8.8.8.8"
    echo ""
    read -p "Enter IP address manually? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter target server IP: " RESOLVED_IP
        if [[ ! "$RESOLVED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${RED}[ERROR]${NC} Invalid IP address format"
            exit 1
        fi
    else
        exit 1
    fi
fi

echo -e "${GREEN}[INFO]${NC} ✓ Resolved $DEST_HOSTNAME → $RESOLVED_IP"

# Detect network interface - NO FUNCTIONS, direct code
if [[ -n "$USER_INTERFACE" ]]; then
    if ip link show "$USER_INTERFACE" &> /dev/null; then
        INTERFACE="$USER_INTERFACE"
    else
        echo -e "${YELLOW}[WARN]${NC} Specified interface '$USER_INTERFACE' not found, auto-detecting..."
        INTERFACE=$(ip route | grep default | head -1 | awk '{print $5}')
    fi
else
    INTERFACE=$(ip route | grep default | head -1 | awk '{print $5}')
fi

if [[ -z "$INTERFACE" ]]; then
    INTERFACE="eth0"  # fallback
fi

echo -e "${GREEN}[INFO]${NC} Using network interface: $INTERFACE"

# Check and enable IP forwarding
echo -e "${GREEN}[INFO]${NC} Checking IP forwarding status..."

CURRENT_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)

if [[ "$CURRENT_FORWARD" == "1" ]]; then
    echo -e "${GREEN}[INFO]${NC} ✓ IP forwarding is already enabled"
else
    echo -e "${YELLOW}[WARN]${NC} IP forwarding is disabled, enabling it now..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    if [[ $(cat /proc/sys/net/ipv4/ip_forward) == "1" ]]; then
        echo -e "${GREEN}[INFO]${NC} ✓ IP forwarding enabled temporarily"
    else
        echo -e "${RED}[ERROR]${NC} Failed to enable IP forwarding"
        exit 1
    fi
fi

# Check permanent configuration
SYSCTL_STATUS=""
if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
    SYSCTL_STATUS=$(grep "^net.ipv4.ip_forward" /etc/sysctl.conf | cut -d'=' -f2 | tr -d ' ')
fi

if [[ "$SYSCTL_STATUS" == "1" ]]; then
    echo -e "${GREEN}[INFO]${NC} ✓ IP forwarding is permanently enabled"
else
    echo -e "${YELLOW}[WARN]${NC} Making IP forwarding permanent..."
    cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
        sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
    else
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi
    
    sysctl -p > /dev/null 2>&1 && echo -e "${GREEN}[INFO]${NC} ✓ Applied sysctl changes" || echo -e "${YELLOW}[WARN]${NC} Warning: Failed to apply sysctl changes"
fi

# Setup nftables service
echo -e "${GREEN}[INFO]${NC} Setting up nftables service..."

# Install nftables if not present
if ! command -v nft &> /dev/null; then
    echo -e "${GREEN}[INFO]${NC} Installing nftables..."
    apt update && apt install -y nftables
fi

# Stop iptables services
systemctl stop iptables 2>/dev/null || true
systemctl disable iptables 2>/dev/null || true

# Enable and start nftables
systemctl enable nftables
systemctl start nftables
sleep 2

if ! systemctl is-active --quiet nftables; then
    echo -e "${RED}[ERROR]${NC} Failed to start nftables service"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} ✓ nftables service is running"

# Test connectivity
echo -e "${GREEN}[INFO]${NC} Testing connectivity to $RESOLVED_IP..."

if ping -c 1 -W 3 "$RESOLVED_IP" &> /dev/null; then
    RTT=$(ping -c 1 -W 3 "$RESOLVED_IP" 2>/dev/null | grep "time=" | sed 's/.*time=\([0-9.]*\).*/\1/')
    echo -e "${GREEN}[INFO]${NC} ✓ Destination server is reachable (${RTT}ms)"
else
    echo -e "${YELLOW}[WARN]${NC} ✗ Destination server is not reachable (may still work for forwarding)"
fi

# Create port forwarding rules
echo -e "${GREEN}[INFO]${NC} Creating port forwarding rules..."
echo -e "${GREEN}[INFO]${NC} Interface: $INTERFACE"
echo -e "${GREEN}[INFO]${NC} Destination: $DEST_HOSTNAME → $RESOLVED_IP"
echo -e "${GREEN}[INFO]${NC} Port range: $PORT_START-$PORT_END"

# Remove existing table if present
nft delete table inet port_forward 2>/dev/null || true

# Create new table and chains with proper syntax
nft add table inet port_forward
nft add chain inet port_forward prerouting '{ type nat hook prerouting priority 100; }'
nft add chain inet port_forward postrouting '{ type nat hook postrouting priority 100; }'
nft add chain inet port_forward input '{ type filter hook input priority 0; policy accept; }'
nft add chain inet port_forward forward '{ type filter hook forward priority 0; policy accept; }'

# Add connection tracking rules
nft add rule inet port_forward input ct state related,established accept
nft add rule inet port_forward forward ct state related,established accept

# Add port forwarding rules
RULE_COUNT=0
TOTAL_PORTS=$((PORT_END - PORT_START + 1))

for port in $(seq "$PORT_START" "$PORT_END"); do
    # DNAT rules (TCP/UDP) - using clean variables
    nft add rule inet port_forward prerouting iifname "$INTERFACE" ip protocol tcp tcp dport "$port" dnat to "$RESOLVED_IP:$port"
    nft add rule inet port_forward prerouting iifname "$INTERFACE" ip protocol udp udp dport "$port" dnat to "$RESOLVED_IP:$port"
    
    # MASQUERADE rules (TCP/UDP)
    nft add rule inet port_forward postrouting ip daddr "$RESOLVED_IP" ip protocol tcp tcp dport "$port" masquerade
    nft add rule inet port_forward postrouting ip daddr "$RESOLVED_IP" ip protocol udp udp dport "$port" masquerade
    
    # ACCEPT rules (TCP/UDP)
    nft add rule inet port_forward input ip protocol tcp tcp dport "$port" accept
    nft add rule inet port_forward input ip protocol udp udp dport "$port" accept
    nft add rule inet port_forward forward ip protocol tcp tcp dport "$port" accept
    nft add rule inet port_forward forward ip protocol udp udp dport "$port" accept
    
    RULE_COUNT=$((RULE_COUNT + 1))
    
    # Show progress every 50 ports
    if [[ $((RULE_COUNT % 50)) -eq 0 ]] || [[ $RULE_COUNT -eq $TOTAL_PORTS ]]; then
        echo -e "${GREEN}[INFO]${NC} Progress: $RULE_COUNT/$TOTAL_PORTS ports configured"
    fi
done

echo -e "${GREEN}[INFO]${NC} ✓ Added forwarding rules for $RULE_COUNT ports"

# Save configuration
echo -e "${GREEN}[INFO]${NC} Saving configuration..."

mkdir -p /etc/nftables.d

cat > /etc/nftables.d/port_forward.nft << EOF
#!/usr/sbin/nft -f
# Port forwarding rules for ports $PORT_START-$PORT_END to $DEST_HOSTNAME
# Generated on $(date) by port-forward script
# Interface: $INTERFACE
# Resolved IP: $RESOLVED_IP

table inet port_forward {
    chain prerouting {
        type nat hook prerouting priority 100; policy accept;
$(for port in $(seq "$PORT_START" "$PORT_END"); do
    echo "        iifname \"$INTERFACE\" ip protocol tcp tcp dport $port dnat to $RESOLVED_IP:$port"
    echo "        iifname \"$INTERFACE\" ip protocol udp udp dport $port dnat to $RESOLVED_IP:$port"
done)
    }

    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
$(for port in $(seq "$PORT_START" "$PORT_END"); do
    echo "        ip daddr $RESOLVED_IP ip protocol tcp tcp dport $port masquerade"
    echo "        ip daddr $RESOLVED_IP ip protocol udp udp dport $port masquerade"
done)
    }

    chain input {
        type filter hook input priority 0; policy accept;
        ct state related,established accept
$(for port in $(seq "$PORT_START" "$PORT_END"); do
    echo "        ip protocol tcp tcp dport $port accept"
    echo "        ip protocol udp udp dport $port accept"
done)
    }

    chain forward {
        type filter hook forward priority 0; policy accept;
        ct state related,established accept
$(for port in $(seq "$PORT_START" "$PORT_END"); do
    echo "        ip protocol tcp tcp dport $port accept"
    echo "        ip protocol udp udp dport $port accept"
done)
    }
}
EOF

# Add to main configuration
if ! grep -q "include \"/etc/nftables.d/port_forward.nft\"" /etc/nftables.conf 2>/dev/null; then
    echo 'include "/etc/nftables.d/port_forward.nft"' >> /etc/nftables.conf
fi

echo -e "${GREEN}[INFO]${NC} ✓ Configuration saved to: /etc/nftables.d/port_forward.nft"

# Create management script
echo -e "${GREEN}[INFO]${NC} Creating management script..."

cat > /usr/local/bin/port-forward-manager << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "Starting port forwarding..."
        systemctl start nftables
        ;;
    stop)
        echo "Stopping port forwarding..."
        nft delete table inet port_forward 2>/dev/null || true
        ;;
    restart)
        echo "Restarting port forwarding..."
        systemctl restart nftables
        ;;
    status)
        echo "=== Port Forwarding Status ==="
        echo -n "nftables service: "
        systemctl is-active nftables && echo "Active" || echo "Inactive"
        echo -n "Rules table: "
        nft list table inet port_forward 2>/dev/null >/dev/null && echo "Loaded" || echo "Not found"
        if nft list table inet port_forward 2>/dev/null >/dev/null; then
            echo -n "NAT rules: "
            nft list table inet port_forward | grep -c "dnat\|masquerade"
        fi
        echo -n "IP forwarding: "
        [[ $(cat /proc/sys/net/ipv4/ip_forward) == "1" ]] && echo "Enabled" || echo "Disabled"
        ;;
    reload)
        echo "Reloading nftables configuration..."
        nft -f /etc/nftables.conf
        ;;
    rules)
        echo "=== Current Port Forwarding Rules ==="
        nft list table inet port_forward 2>/dev/null || echo "No rules found"
        ;;
    *)
        echo "Port Forward Manager"
        echo "Usage: $0 {start|stop|restart|status|reload|rules}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/port-forward-manager
echo -e "${GREEN}[INFO]${NC} ✓ Management script created: port-forward-manager"

# Verify configuration
echo -e "${GREEN}[INFO]${NC} Verifying configuration..."

ERRORS=0

if ! systemctl is-active --quiet nftables; then
    echo -e "${RED}[ERROR]${NC} ✗ nftables service is not running"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}[INFO]${NC} ✓ nftables service is running"
fi

if ! nft list tables | grep -q "inet port_forward"; then
    echo -e "${RED}[ERROR]${NC} ✗ port_forward table not found"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}[INFO]${NC} ✓ port_forward table exists"
    NAT_RULES=$(nft list table inet port_forward | grep -c "dnat\|masquerade")
    echo -e "${GREEN}[INFO]${NC} ✓ NAT rules loaded: $NAT_RULES"
fi

if [[ $(cat /proc/sys/net/ipv4/ip_forward) != "1" ]]; then
    echo -e "${RED}[ERROR]${NC} ✗ IP forwarding is not enabled"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}[INFO]${NC} ✓ IP forwarding is enabled"
fi

# Show final summary
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${BLUE}========================================="
echo "    Port Forwarding Setup Complete"
echo -e "=========================================${NC}"
echo ""
echo "Configuration Summary:"
echo "  Local IP:      $LOCAL_IP"
echo "  Interface:     $INTERFACE"
echo "  Destination:   $DEST_HOSTNAME → $RESOLVED_IP"
echo "  Port Range:    $PORT_START-$PORT_END (TCP/UDP)"
echo "  Total Ports:   $((PORT_END - PORT_START + 1))"
echo ""
echo "Management Commands:"
echo "  port-forward-manager status    # Check status"
echo "  port-forward-manager restart   # Restart service"
echo "  port-forward-manager rules     # View rules"
echo ""
echo "Test Commands:"
echo "  telnet $LOCAL_IP $PORT_START"
echo "  nc -zv $LOCAL_IP $PORT_START-$((PORT_START + 4))"
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ Port forwarding is now active!${NC}"
else
    echo -e "${RED}✗ Setup completed but verification failed ($ERRORS errors)${NC}"
fi
echo -e "${BLUE}=========================================${NC}"
