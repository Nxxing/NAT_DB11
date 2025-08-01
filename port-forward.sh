#!/bin/bash

# Debian 11 Port Forward Script - Optimized for curl | bash -s --
# Usage: curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- <dest_ip> <port_start> <port_end> [interface]
# Example: curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- nx05.servegame.com 38054 38303

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
    echo "Parameters:"
    echo "  dest_ip     Target server IP or hostname"
    echo "  port_start  Starting port number"
    echo "  port_end    Ending port number"
    echo "  interface   Network interface (optional, auto-detect by default)"
    echo ""
    echo "Examples:"
    echo "  curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- nx05.servegame.com 38054 38303"
    echo "  curl -sSL https://raw.githubusercontent.com/Nxxing/NAT_DB11/main/port-forward.sh | sudo bash -s -- 192.168.1.100 29287 29291 eth0"
    echo ""
}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Validate parameters
validate_params() {
    if [[ $# -lt 3 || $# -gt 4 ]]; then
        log_error "Invalid number of parameters"
        echo ""
        show_usage
        exit 1
    fi

    if [[ -z "$1" ]]; then
        log_error "Destination IP/hostname cannot be empty"
        exit 1
    fi

    if ! [[ "$2" =~ ^[0-9]+$ ]] || ! [[ "$3" =~ ^[0-9]+$ ]]; then
        log_error "Port numbers must be integers"
        exit 1
    fi

    if [[ $2 -lt 1 || $2 -gt 65535 || $3 -lt 1 || $3 -gt 65535 ]]; then
        log_error "Port numbers must be between 1 and 65535"
        exit 1
    fi

    if [[ $2 -gt $3 ]]; then
        log_error "Start port ($2) cannot be greater than end port ($3)"
        exit 1
    fi

    if [[ -n "$4" ]] && ! ip link show "$4" &> /dev/null; then
        log_error "Network interface '$4' does not exist"
        exit 1
    fi
}

# Resolve hostname to IP address
resolve_hostname() {
    local hostname="$1"
    local resolved_ip
    
    # Check if it's already an IP address
    if [[ "$hostname" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$hostname"
        return 0
    fi
    
    log_info "Resolving hostname: $hostname"
    
    # Try nslookup
    resolved_ip=$(nslookup "$hostname" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -1)
    if [[ -n "$resolved_ip" && "$resolved_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$resolved_ip"
        return 0
    fi
    
    # Try getent
    resolved_ip=$(getent hosts "$hostname" 2>/dev/null | awk '{print $1}' | head -1)
    if [[ -n "$resolved_ip" && "$resolved_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$resolved_ip"
        return 0
    fi
    
    # Try dig
    if command -v dig &> /dev/null; then
        resolved_ip=$(dig +short "$hostname" 2>/dev/null | head -1)
        if [[ -n "$resolved_ip" && "$resolved_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$resolved_ip"
            return 0
        fi
    fi
    
    return 1
}

# Detect network interface
detect_interface() {
    local interface="$1"
    
    if [[ -n "$interface" ]]; then
        if ip link show "$interface" &> /dev/null; then
            echo "$interface"
            return
        else
            log_warn "Specified interface '$interface' not found"
        fi
    fi

    # Auto-detect default interface
    local default_iface
    default_iface=$(ip route | grep default | head -1 | awk '{print $5}')
    
    if [[ -n "$default_iface" ]]; then
        log_info "Auto-detected network interface: $default_iface"
        echo "$default_iface"
    else
        log_error "Could not detect network interface"
        exit 1
    fi
}

# Check and enable IP forwarding
enable_ip_forwarding() {
    log_info "Checking IP forwarding status..."
    
    local current_status
    current_status=$(cat /proc/sys/net/ipv4/ip_forward)
    
    if [[ "$current_status" == "1" ]]; then
        log_info "✓ IP forwarding is already enabled"
    else
        log_warn "IP forwarding is disabled, enabling it now..."
        echo 1 > /proc/sys/net/ipv4/ip_forward
        
        if [[ $(cat /proc/sys/net/ipv4/ip_forward) == "1" ]]; then
            log_info "✓ IP forwarding enabled temporarily"
        else
            log_error "Failed to enable IP forwarding"
            exit 1
        fi
    fi
    
    # Check permanent configuration
    local sysctl_status=""
    if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
        sysctl_status=$(grep "^net.ipv4.ip_forward" /etc/sysctl.conf | cut -d'=' -f2 | tr -d ' ')
    fi
    
    if [[ "$sysctl_status" == "1" ]]; then
        log_info "✓ IP forwarding is permanently enabled"
    else
        log_warn "Making IP forwarding permanent..."
        cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        
        if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
            sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
        else
            echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        fi
        
        sysctl -p > /dev/null 2>&1 && log_info "✓ Applied sysctl changes" || log_warn "Warning: Failed to apply sysctl changes"
    fi
}

# Setup nftables service
setup_nftables() {
    log_info "Setting up nftables service..."
    
    # Install nftables if not present
    if ! command -v nft &> /dev/null; then
        log_info "Installing nftables..."
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
        log_error "Failed to start nftables service"
        exit 1
    fi

    log_info "✓ nftables service is running"
}

# Test connectivity
test_connectivity() {
    local dest_ip="$1"
    
    log_info "Testing connectivity to $dest_ip..."
    
    if ping -c 1 -W 3 "$dest_ip" &> /dev/null; then
        local rtt
        rtt=$(ping -c 1 -W 3 "$dest_ip" 2>/dev/null | grep "time=" | sed 's/.*time=\([0-9.]*\).*/\1/')
        log_info "✓ Destination server is reachable (${rtt}ms)"
    else
        log_warn "✗ Destination server is not reachable (may still work for forwarding)"
    fi
}

# Create port forwarding rules
create_forwarding_rules() {
    local dest_ip="$1"
    local resolved_ip="$2"
    local port_start="$3"
    local port_end="$4"
    local interface="$5"
    
    log_info "Creating port forwarding rules..."
    log_info "Interface: $interface"
    log_info "Destination: $dest_ip → $resolved_ip"
    log_info "Port range: $port_start-$port_end"
    
    # Remove existing table if present
    nft delete table inet port_forward 2>/dev/null || true
    
    # Create new table and chains
    nft add table inet port_forward
    nft add chain inet port_forward prerouting { type nat hook prerouting priority 100 \; }
    nft add chain inet port_forward postrouting { type nat hook postrouting priority 100 \; }
    nft add chain inet port_forward input { type filter hook input priority 0 \; policy accept \; }
    nft add chain inet port_forward forward { type filter hook forward priority 0 \; policy accept \; }
    
    # Add connection tracking rules
    nft add rule inet port_forward input ct state related,established accept
    nft add rule inet port_forward forward ct state related,established accept
    
    # Add port forwarding rules
    local rule_count=0
    local total_ports=$((port_end - port_start + 1))
    
    for port in $(seq "$port_start" "$port_end"); do
        # DNAT rules (TCP/UDP) - Must specify 'ip protocol' for inet table
        nft add rule inet port_forward prerouting iifname "$interface" ip protocol tcp tcp dport "$port" dnat to "$resolved_ip:$port"
        nft add rule inet port_forward prerouting iifname "$interface" ip protocol udp udp dport "$port" dnat to "$resolved_ip:$port"
        
        # MASQUERADE rules (TCP/UDP)
        nft add rule inet port_forward postrouting ip daddr "$resolved_ip" ip protocol tcp tcp dport "$port" masquerade
        nft add rule inet port_forward postrouting ip daddr "$resolved_ip" ip protocol udp udp dport "$port" masquerade
        
        # ACCEPT rules (TCP/UDP)
        nft add rule inet port_forward input ip protocol tcp tcp dport "$port" accept
        nft add rule inet port_forward input ip protocol udp udp dport "$port" accept
        nft add rule inet port_forward forward ip protocol tcp tcp dport "$port" accept
        nft add rule inet port_forward forward ip protocol udp udp dport "$port" accept
        
        rule_count=$((rule_count + 1))
        
        # Show progress every 50 ports
        if [[ $((rule_count % 50)) -eq 0 ]] || [[ $rule_count -eq $total_ports ]]; then
            log_info "Progress: $rule_count/$total_ports ports configured"
        fi
    done
    
    log_info "✓ Added forwarding rules for $rule_count ports"
}

# Save configuration
save_configuration() {
    local dest_ip="$1"
    local resolved_ip="$2"
    local port_start="$3"
    local port_end="$4"
    local interface="$5"
    
    log_info "Saving configuration..."
    
    mkdir -p /etc/nftables.d
    
    cat > /etc/nftables.d/port_forward.nft << EOF
#!/usr/sbin/nft -f
# Port forwarding rules for ports $port_start-$port_end to $dest_ip
# Generated on $(date) by port-forward script
# Interface: $interface
# Resolved IP: $resolved_ip

table inet port_forward {
    chain prerouting {
        type nat hook prerouting priority 100; policy accept;
$(for port in $(seq "$port_start" "$port_end"); do
    echo "        iifname \"$interface\" ip protocol tcp tcp dport $port dnat to $resolved_ip:$port"
    echo "        iifname \"$interface\" ip protocol udp udp dport $port dnat to $resolved_ip:$port"
done)
    }

    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
$(for port in $(seq "$port_start" "$port_end"); do
    echo "        ip daddr $resolved_ip ip protocol tcp tcp dport $port masquerade"
    echo "        ip daddr $resolved_ip ip protocol udp udp dport $port masquerade"
done)
    }

    chain input {
        type filter hook input priority 0; policy accept;
        ct state related,established accept
$(for port in $(seq "$port_start" "$port_end"); do
    echo "        ip protocol tcp tcp dport $port accept"
    echo "        ip protocol udp udp dport $port accept"
done)
    }

    chain forward {
        type filter hook forward priority 0; policy accept;
        ct state related,established accept
$(for port in $(seq "$port_start" "$port_end"); do
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
    
    log_info "✓ Configuration saved to: /etc/nftables.d/port_forward.nft"
}

# Create management script
create_manager() {
    log_info "Creating management script..."
    
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
    log_info "✓ Management script created: port-forward-manager"
}

# Verify configuration
verify_configuration() {
    log_info "Verifying configuration..."
    
    local errors=0
    
    # Check nftables service
    if ! systemctl is-active --quiet nftables; then
        log_error "✗ nftables service is not running"
        errors=$((errors + 1))
    else
        log_info "✓ nftables service is running"
    fi
    
    # Check port_forward table
    if ! nft list tables | grep -q "inet port_forward"; then
        log_error "✗ port_forward table not found"
        errors=$((errors + 1))
    else
        log_info "✓ port_forward table exists"
        local nat_rules
        nat_rules=$(nft list table inet port_forward | grep -c "dnat\|masquerade")
        log_info "✓ NAT rules loaded: $nat_rules"
    fi
    
    # Check IP forwarding
    if [[ $(cat /proc/sys/net/ipv4/ip_forward) != "1" ]]; then
        log_error "✗ IP forwarding is not enabled"
        errors=$((errors + 1))
    else
        log_info "✓ IP forwarding is enabled"
    fi
    
    return $errors
}

# Show final summary
show_summary() {
    local dest_ip="$1"
    local resolved_ip="$2"
    local port_start="$3"
    local port_end="$4"
    local interface="$5"
    local local_ip
    
    local_ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${BLUE}========================================="
    echo "    Port Forwarding Setup Complete"
    echo -e "=========================================${NC}"
    echo ""
    echo "Configuration Summary:"
    echo "  Local IP:      $local_ip"
    echo "  Interface:     $interface"
    echo "  Destination:   $dest_ip → $resolved_ip"
    echo "  Port Range:    $port_start-$port_end (TCP/UDP)"
    echo "  Total Ports:   $((port_end - port_start + 1))"
    echo ""
    echo "Management Commands:"
    echo "  port-forward-manager status    # Check status"
    echo "  port-forward-manager restart   # Restart service"
    echo "  port-forward-manager rules     # View rules"
    echo ""
    echo "Test Commands:"
    echo "  telnet $local_ip $port_start"
    echo "  nc -zv $local_ip $port_start-$((port_start + 4))"
    echo ""
    echo -e "${GREEN}✓ Port forwarding is now active!${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

# Main function - receives parameters from command line
main() {
    # Handle help or no parameters
    if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" || $# -eq 0 ]]; then
        show_usage
        exit 0
    fi
    
    # Check root privileges
    check_root
    
    # Validate parameters
    validate_params "$@"
    
    # Parse command line parameters
    local dest_ip="$1"
    local port_start="$2"
    local port_end="$3"
    local interface="$4"
    
    echo -e "${BLUE}========================================="
    echo "    Debian 11 Port Forwarding Setup"
    echo -e "=========================================${NC}"
    echo ""
    echo "Parameters:"
    echo "  Destination:   $dest_ip"
    echo "  Port Range:    $port_start-$port_end"
    echo "  Interface:     ${interface:-auto-detect}"
    echo "  Total Ports:   $((port_end - port_start + 1))"
    echo ""
    
    # Resolve hostname
    local resolved_ip
    if ! resolved_ip=$(resolve_hostname "$dest_ip"); then
        log_error "Failed to resolve hostname: $dest_ip"
        echo ""
        echo "Troubleshooting DNS resolution:"
        echo "1. Check if hostname is correct: $dest_ip"
        echo "2. Test DNS: nslookup $dest_ip"
        echo "3. Check network: ping 8.8.8.8"
        echo ""
        read -p "Enter IP address manually? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter target server IP: " resolved_ip
            if [[ ! "$resolved_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_error "Invalid IP address format"
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    log_info "✓ Resolved $dest_ip → $resolved_ip"
    
    # Detect interface
    interface=$(detect_interface "$interface")
    
    # Setup system
    enable_ip_forwarding
    setup_nftables
    test_connectivity "$resolved_ip"
    
    # Configure forwarding
    create_forwarding_rules "$dest_ip" "$resolved_ip" "$port_start" "$port_end" "$interface"
    save_configuration "$dest_ip" "$resolved_ip" "$port_start" "$port_end" "$interface"
    create_manager
    
    # Verify and show results
    if verify_configuration; then
        show_summary "$dest_ip" "$resolved_ip" "$port_start" "$port_end" "$interface"
    else
        log_error "Setup completed but verification failed"
        exit 1
    fi
}

# Execute main function with all command line arguments
main "$@"
