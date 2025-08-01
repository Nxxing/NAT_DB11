#!/bin/bash

# Debian 11 Port Forward - One-Click Installer
# Usage: curl -sSL https://raw.githubusercontent.com/your-username/debian11-port-forward/main/install.sh | sudo bash -s -- <dest_ip> <port_start> <port_end>

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# GitHub repository info
GITHUB_USER="your-username"  # 請替換為您的 GitHub 用戶名
GITHUB_REPO="debian11-port-forward"
GITHUB_BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
show_usage() {
    echo "Debian 11 Port Forward - One-Click Installer"
    echo ""
    echo "Usage:"
    echo "  curl -sSL $BASE_URL/install.sh | sudo bash -s -- <dest_ip> <port_start> <port_end> [interface]"
    echo ""
    echo "Examples:"
    echo "  curl -sSL $BASE_URL/install.sh | sudo bash -s -- nx05.servegame.com 38054 38303"
    echo "  curl -sSL $BASE_URL/install.sh | sudo bash -s -- 192.168.1.100 29287 29291 eth0"
    echo ""
    echo "Parameters:"
    echo "  dest_ip     Target server IP or hostname"
    echo "  port_start  Starting port number"
    echo "  port_end    Ending port number"
    echo "  interface   Network interface (optional)"
    echo ""
    echo "Local Installation:"
    echo "  git clone https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
    echo "  cd ${GITHUB_REPO}"
    echo "  sudo ./port-forward.sh <dest_ip> <port_start> <port_end>"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Download and execute main script
download_and_execute() {
    local dest_ip="$1"
    local port_start="$2"
    local port_end="$3"
    local interface="$4"
    
    log_info "Downloading port-forward script from GitHub..."
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Download main script
    if curl -sSL "$BASE_URL/port-forward.sh" -o "$temp_dir/port-forward.sh"; then
        log_info "✓ Downloaded port-forward.sh"
    else
        log_error "Failed to download port-forward.sh"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Make executable
    chmod +x "$temp_dir/port-forward.sh"
    
    # Execute with parameters
    log_info "Executing port forwarding setup..."
    
    if [[ -n "$interface" ]]; then
        "$temp_dir/port-forward.sh" "$dest_ip" "$port_start" "$port_end" "$interface"
    else
        "$temp_dir/port-forward.sh" "$dest_ip" "$port_start" "$port_end"
    fi
    
    # Download test script (optional)
    log_info "Downloading test script..."
    if curl -sSL "$BASE_URL/test-port-forward.sh" -o "/usr/local/bin/test-port-forward"; then
        chmod +x "/usr/local/bin/test-port-forward"
        log_info "✓ Test script installed to /usr/local/bin/test-port-forward"
    else
        log_warn "Failed to download test script (non-critical)"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_info "✓ Installation completed successfully!"
    echo ""
    echo "Test your configuration:"
    echo "  test-port-forward $dest_ip $port_start $port_end"
    echo ""
    echo "Management commands:"
    echo "  port-forward-manager status"
    echo "  port-forward-manager restart"
    echo "  port-forward-manager rules"
}

# Main function
main() {
    echo -e "${BLUE}=========================================="
    echo "  Debian 11 Port Forward Installer"
    echo -e "==========================================${NC}"
    echo ""
    
    # Handle help
    if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" || $# -eq 0 ]]; then
        show_usage
        exit 0
    fi
    
    # Check root privileges
    check_root
    
    # Validate parameters
    if [[ $# -lt 3 ]]; then
        log_error "Missing required parameters"
        show_usage
        exit 1
    fi
    
    local dest_ip="$1"
    local port_start="$2"
    local port_end="$3"
    local interface="$4"
    
    # Basic validation
    if [[ -z "$dest_ip" ]]; then
        log_error "Destination IP/hostname cannot be empty"
        exit 1
    fi
    
    if ! [[ "$port_start" =~ ^[0-9]+$ ]] || ! [[ "$port_end" =~ ^[0-9]+$ ]]; then
        log_error "Port numbers must be integers"
        exit 1
    fi
    
    if [[ $port_start -gt $port_end ]]; then
        log_error "Start port cannot be greater than end port"
        exit 1
    fi
    
    echo "Configuration:"
    echo "  Destination: $dest_ip"
    echo "  Port Range: $port_start-$port_end"
    echo "  Interface: ${interface:-auto-detect}"
    echo ""
    
    # Confirmation
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Download and execute
    download_and_execute "$dest_ip" "$port_start" "$port_end" "$interface"
}

# Run main function
main "$@"
