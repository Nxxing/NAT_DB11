# Debian 11 Port Forwarding with nftables

Easy-to-use port forwarding setup for Debian 11 using nftables.

## Quick Start

```bash
# Setup port forwarding
sudo ./port-forward.sh <dest_ip> <port_start> <port_end>

# Test configuration  
sudo ./test-port-forward.sh <dest_ip> <port_start> <port_end>

# Forward ports 38054-38303 to nx05.servegame.com
sudo ./port-forward.sh nx05.servegame.com 38054 38303

# Test the configuration
sudo ./test-port-forward.sh nx05.servegame.com 38054 38303 --detailed
