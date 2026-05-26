#!/bin/bash
# ============================================================
# MONAD VALIDATOR MANAGEMENT TOOL v1.0
# Author: MegaNode
# Description: All-in-one tool for Monad validator operations
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Globals
NETWORK=""
CHAIN=""
PUBLIC_RPC=""
LOCAL_RPC=""
LOCAL_PORT=""
MF_BUCKET="https://bucket.monadinfra.com"

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

print_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}  ${BOLD}${CYAN}⬡ MONAD VALIDATOR MANAGEMENT TOOL v1.0${NC}             ${PURPLE} ║${NC}"
    echo -e "${PURPLE}║${NC}  ${BOLD}MegaNode${NC}                                           ${PURPLE} ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_separator() {
    echo -e "${BLUE}──────────────────────────────────────────────────────${NC}"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

press_enter() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

hex_to_dec() {
    printf '%d\n' "$1" 2>/dev/null || echo 0
}

get_block_number() {
    local rpc_url="$1"
    local hex
    hex=$(curl -s --connect-timeout 5 --max-time 10 -X POST "$rpc_url" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | jq -r '.result' 2>/dev/null)
    if [ -n "$hex" ] && [ "$hex" != "null" ]; then
        hex_to_dec "$hex"
    else
        echo 0
    fi
}

get_balance_mon() {
    local address="$1"
    local hex
    hex=$(curl -s --connect-timeout 5 --max-time 10 -X POST "$LOCAL_RPC" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$address\",\"latest\"],\"id\":1}" 2>/dev/null | jq -r '.result' 2>/dev/null)
    if [ -n "$hex" ] && [ "$hex" != "null" ]; then
        python3 -c "print(f'{int(\"$hex\", 16) / 1e18:.4f}')" 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

# ============================================================
# NETWORK SELECTION
# ============================================================

select_network() {
    print_banner
    echo -e "${BOLD}Select Network:${NC}"
    print_separator
    echo -e "  ${GREEN}1)${NC} Monad Testnet"
    echo -e "  ${GREEN}2)${NC} Monad Mainnet"
    echo -e "  ${RED}0)${NC} Exit"
    print_separator
    echo ""
    read -rp "$(echo -e ${CYAN}'Enter choice [1/2/0]: '${NC})" choice

    case $choice in
        1)
            NETWORK="TESTNET"
            CHAIN="monad_testnet"
            PUBLIC_RPC="https://testnet-rpc.monad.xyz"
            # Auto-detect local RPC port
            LOCAL_PORT=$(ss -tlnp 2>/dev/null | grep monad-rpc | awk '{print $4}' | grep -oP ':\K[0-9]+' | head -1)
            LOCAL_PORT=${LOCAL_PORT:-8080}
            LOCAL_RPC="http://localhost:${LOCAL_PORT}"
            ;;
        2)
            NETWORK="MAINNET"
            CHAIN="monad_mainnet"
            PUBLIC_RPC="https://rpc.monad.xyz"
            LOCAL_PORT=$(ss -tlnp 2>/dev/null | grep monad-rpc | awk '{print $4}' | grep -oP ':\K[0-9]+' | head -1)
            LOCAL_PORT=${LOCAL_PORT:-8080}
            LOCAL_RPC="http://localhost:${LOCAL_PORT}"
            ;;
        0)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            select_network
            ;;
    esac
}

# ============================================================
# MENU FUNCTIONS
# ============================================================

# 1. Quick Status Check
quick_status() {
    print_banner
    echo -e "${BOLD}⬡ Quick Status Check [${NETWORK}]${NC}"
    print_separator

    # Services
    echo -e "\n${BOLD}Services:${NC}"
    for svc in monad-bft monad-execution monad-rpc; do
        local status
        status=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
        if [ "$status" = "active" ]; then
            echo -e "  ${GREEN}●${NC} $svc: ${GREEN}active${NC}"
        elif [ "$status" = "failed" ]; then
            echo -e "  ${RED}●${NC} $svc: ${RED}failed${NC}"
        else
            echo -e "  ${YELLOW}●${NC} $svc: ${YELLOW}$status${NC}"
        fi
    done

    # Block number
    echo -e "\n${BOLD}Local Block:${NC}"
    local block
    block=$(get_block_number "$LOCAL_RPC")
    if [ "$block" -gt 0 ] 2>/dev/null; then
        echo -e "  Block: ${GREEN}$block${NC}"
    else
        echo -e "  Block: ${YELLOW}Waiting for sync...${NC}"
    fi

    # Memory & CPU
    echo -e "\n${BOLD}Resources:${NC}"
    echo -e "  RAM: $(free -h | awk '/Mem:/{printf "%s / %s (%s used)", $3, $2, $3}')"
    echo -e "  Swap: $(free -h | awk '/Swap:/{printf "%s / %s", $3, $2}')"
    echo -e "  Swappiness: $(cat /proc/sys/vm/swappiness)"

    # Uptime
    echo -e "\n${BOLD}Uptime:${NC}"
    for svc in monad-bft monad-execution; do
        local since
        since=$(systemctl show "$svc" --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2)
        if [ -n "$since" ]; then
            echo -e "  $svc: since $since"
        fi
    done

    press_enter
}

# 2. Sync Verification
sync_check() {
    print_banner
    echo -e "${BOLD}⬡ Sync Verification [${NETWORK}]${NC}"
    print_separator

    print_info "Fetching network block..."
    local network_block
    network_block=$(get_block_number "$PUBLIC_RPC")

    print_info "Fetching local block..."
    local local_block
    local_block=$(get_block_number "$LOCAL_RPC")

    echo ""
    echo -e "  ${BOLD}Network:${NC} ${CYAN}$network_block${NC}"
    echo -e "  ${BOLD}Local:${NC}   ${CYAN}$local_block${NC}"

    if [ "$local_block" -gt 0 ] && [ "$network_block" -gt 0 ] 2>/dev/null; then
        local diff=$((network_block - local_block))
        local percent
        percent=$(awk "BEGIN {printf \"%.4f\", ($local_block / $network_block) * 100}")

        if [ "$diff" -le 10 ] && [ "$diff" -ge -100 ]; then
            echo -e "  ${BOLD}Status:${NC}  ${GREEN}✓ FULLY SYNCED${NC}"
        elif [ "$diff" -gt 10 ] && [ "$diff" -le 1000 ]; then
            echo -e "  ${BOLD}Status:${NC}  ${YELLOW}⏳ Almost synced (${diff} blocks behind)${NC}"
        else
            echo -e "  ${BOLD}Status:${NC}  ${RED}⏳ Syncing... (${diff} blocks behind)${NC}"
        fi
        echo -e "  ${BOLD}Sync:${NC}    ${percent}%"
        echo -e "  ${BOLD}Diff:${NC}    ${diff} blocks"
    else
        echo -e "  ${BOLD}Status:${NC}  ${YELLOW}Cannot determine sync status${NC}"
    fi

    press_enter
}

# 3. Service Status (detailed)
service_status() {
    print_banner
    echo -e "${BOLD}⬡ Service Status [${NETWORK}]${NC}"
    print_separator

    sudo systemctl status monad-bft monad-execution monad-rpc --no-pager -l 2>/dev/null | head -60

    press_enter
}

# 4. View Logs
view_logs() {
    print_banner
    echo -e "${BOLD}⬡ View Logs [${NETWORK}]${NC}"
    print_separator
    echo -e "  ${GREEN}1)${NC} monad-bft logs (last 50)"
    echo -e "  ${GREEN}2)${NC} monad-execution logs (last 50)"
    echo -e "  ${GREEN}3)${NC} monad-rpc logs (last 50)"
    echo -e "  ${GREEN}4)${NC} monad-bft logs (follow/realtime)"
    echo -e "  ${GREEN}5)${NC} monad-execution logs (follow/realtime)"
    echo -e "  ${GREEN}6)${NC} Errors & Warnings (last 1 hour)"
    echo -e "  ${RED}0)${NC} Back"
    print_separator
    echo ""
    read -rp "$(echo -e ${CYAN}'Enter choice: '${NC})" choice

    case $choice in
        1) journalctl -u monad-bft -n 50 --no-pager; press_enter ;;
        2) journalctl -u monad-execution -n 50 --no-pager; press_enter ;;
        3) journalctl -u monad-rpc -n 50 --no-pager; press_enter ;;
        4) echo -e "${YELLOW}Press Ctrl+C to exit...${NC}"; journalctl -u monad-bft -f ;;
        5) echo -e "${YELLOW}Press Ctrl+C to exit...${NC}"; journalctl -u monad-execution -f ;;
        6)
            echo -e "\n${BOLD}Errors & Warnings (last 1 hour):${NC}"
            journalctl -u monad-bft -u monad-execution -u monad-rpc --since "1 hour ago" --no-pager | grep -iE "error|warn|fail|panic|timeout|crash" | tail -30
            press_enter
            ;;
        0) return ;;
        *) print_error "Invalid choice"; press_enter ;;
    esac
}

# 5. Resource Monitor
resource_monitor() {
    print_banner
    echo -e "${BOLD}⬡ Resource Monitor [${NETWORK}]${NC}"
    print_separator

    # CPU
    echo -e "\n${BOLD}CPU:${NC}"
    echo -e "  Cores: $(nproc)"
    echo -e "  Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
    echo -e "  Load: $(uptime | awk -F'load average:' '{print $2}')"

    # Memory
    echo -e "\n${BOLD}Memory:${NC}"
    free -h | awk '/Mem:/{printf "  Total: %s | Used: %s | Available: %s\n", $2, $3, $7}'
    free -h | awk '/Swap:/{printf "  Swap: %s used / %s total\n", $3, $2}'
    echo -e "  Swappiness: $(cat /proc/sys/vm/swappiness)"

    # Disk
    echo -e "\n${BOLD}Disk:${NC}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS | grep -v "loop"

    # TrieDB
    echo -e "\n${BOLD}TrieDB:${NC}"
    if [ -L /dev/triedb ]; then
        echo -e "  Device: $(readlink -f /dev/triedb)"
        local triedb_size
        triedb_size=$(lsblk -b "$(readlink -f /dev/triedb)" -o SIZE -n 2>/dev/null | head -1)
        if [ -n "$triedb_size" ]; then
            echo -e "  Size: $(echo "$triedb_size" | awk '{printf "%.1f TB", $1/1024/1024/1024/1024}')"
        fi
        # Disk usage from execution log
        local disk_usage
        disk_usage=$(journalctl -u monad-execution -n 20 --no-pager 2>/dev/null | grep -oP 'Disk usage: \K[0-9.]+' | tail -1)
        if [ -n "$disk_usage" ]; then
            echo -e "  Usage: ${disk_usage} ($(awk "BEGIN {printf \"%.1f%%\", $disk_usage * 100}"))"
        fi
    else
        echo -e "  ${YELLOW}/dev/triedb not found${NC}"
    fi

    # CPU Isolation
    echo -e "\n${BOLD}CPU Isolation:${NC}"
    for svc in monad-bft monad-execution; do
        local cpus
        cpus=$(grep "AllowedCPUs" /usr/lib/systemd/system/${svc}.service 2>/dev/null | head -1)
        if [ -n "$cpus" ]; then
            echo -e "  $svc: $cpus"
        fi
    done

    # Chrony
    echo -e "\n${BOLD}Time Sync:${NC}"
    if command -v chronyc &>/dev/null; then
        chronyc tracking 2>/dev/null | grep "System time" | awk '{printf "  Offset: %s %s %s %s %s\n", $4, $5, $6, $7, $8}'
    else
        echo -e "  ${YELLOW}chrony not installed${NC}"
    fi

    press_enter
}

# 6. Wallet Balance
wallet_balance() {
    print_banner
    echo -e "${BOLD}⬡ Wallet Balance Check [${NETWORK}]${NC}"
    print_separator

    read -rp "$(echo -e ${CYAN}'Enter wallet address (0x...): '${NC})" address

    if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Invalid address format"
        press_enter
        return
    fi

    print_info "Fetching balance..."
    local balance
    balance=$(get_balance_mon "$address")
    echo -e "\n  ${BOLD}Address:${NC} $address"
    echo -e "  ${BOLD}Balance:${NC} ${GREEN}${balance} MON${NC}"

    press_enter
}

# 7. Restart Services
restart_services() {
    print_banner
    echo -e "${BOLD}⬡ Restart Services [${NETWORK}]${NC}"
    print_separator
    echo -e "  ${GREEN}1)${NC} Restart ALL (bft + execution + rpc)"
    echo -e "  ${GREEN}2)${NC} Restart monad-bft only"
    echo -e "  ${GREEN}3)${NC} Restart monad-execution only"
    echo -e "  ${GREEN}4)${NC} Restart monad-rpc only"
    echo -e "  ${RED}0)${NC} Back"
    print_separator
    echo ""
    read -rp "$(echo -e ${CYAN}'Enter choice: '${NC})" choice

    case $choice in
        1)
            print_warn "Restarting ALL services..."
            sudo systemctl daemon-reload
            sudo systemctl restart monad-bft monad-execution monad-rpc
            sleep 5
            print_info "Checking status..."
            for svc in monad-bft monad-execution monad-rpc; do
                local status
                status=$(systemctl is-active "$svc" 2>/dev/null)
                if [ "$status" = "active" ]; then
                    print_success "$svc: active"
                else
                    print_error "$svc: $status"
                fi
            done
            ;;
        2) sudo systemctl restart monad-bft; print_success "monad-bft restarted" ;;
        3) sudo systemctl restart monad-execution; print_success "monad-execution restarted" ;;
        4) sudo systemctl restart monad-rpc; print_success "monad-rpc restarted" ;;
        0) return ;;
        *) print_error "Invalid choice" ;;
    esac

    press_enter
}

# 8. Soft Reset
soft_reset() {
    print_banner
    echo -e "${BOLD}⬡ Soft Reset [${NETWORK}]${NC}"
    print_separator
    echo -e "${YELLOW}This will:${NC}"
    echo -e "  - Stop all Monad services"
    echo -e "  - Clear WAL and ledger"
    echo -e "  - Download latest forkpoint"
    echo -e "  - Restart services"
    echo -e ""
    echo -e "${RED}TrieDB will NOT be wiped.${NC}"
    print_separator

    read -rp "$(echo -e ${RED}'Are you sure? [y/N]: '${NC})" confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        print_info "Cancelled."
        press_enter
        return
    fi

    local net
    if [ "$NETWORK" = "TESTNET" ]; then
        net="testnet"
    else
        net="mainnet"
    fi

    print_info "Stopping services..."
    sudo systemctl stop monad-bft monad-execution monad-rpc

    print_info "Clearing WAL..."
    sudo rm -rf /home/monad/monad-bft/wal/*

    print_info "Clearing ledger..."
    sudo rm -rf /home/monad/monad-bft/ledger/*

    print_info "Downloading forkpoint..."
    curl -sSL "$MF_BUCKET/scripts/${net}/download-forkpoint.sh" | bash

    print_info "Updating validators..."
    curl -s "$MF_BUCKET/validators/${net}/validators.toml" -o /home/monad/monad-bft/config/validators/validators.toml
    chown monad:monad /home/monad/monad-bft/config/validators/validators.toml

    print_info "Starting services..."
    sudo systemctl start monad-execution
    sleep 5
    sudo systemctl start monad-bft
    sleep 3
    sudo systemctl start monad-rpc

    sleep 10
    print_info "Checking status..."
    for svc in monad-bft monad-execution monad-rpc; do
        local status
        status=$(systemctl is-active "$svc" 2>/dev/null)
        if [ "$status" = "active" ]; then
            print_success "$svc: active"
        else
            print_error "$svc: $status"
        fi
    done

    press_enter
}

# 9. Hard Reset
hard_reset() {
    print_banner
    echo -e "${BOLD}⬡ Hard Reset [${NETWORK}]${NC}"
    print_separator
    echo -e "${RED}${BOLD}⚠ WARNING: DESTRUCTIVE OPERATION${NC}"
    echo -e "${RED}This will:${NC}"
    echo -e "  - Stop all Monad services"
    echo -e "  - WIPE TrieDB completely"
    echo -e "  - Clear WAL, ledger, and sockets"
    echo -e "  - Re-import snapshot from scratch"
    echo -e "  - Download latest forkpoint & validators"
    echo -e "  - Restart services"
    echo -e ""
    echo -e "${RED}${BOLD}Node will need to re-sync from snapshot!${NC}"
    print_separator

    read -rp "$(echo -e ${RED}'Type YES to confirm hard reset: '${NC})" confirm
    if [ "$confirm" != "YES" ]; then
        print_info "Cancelled."
        press_enter
        return
    fi

    local net
    if [ "$NETWORK" = "TESTNET" ]; then
        net="testnet"
    else
        net="mainnet"
    fi

    print_info "Stopping services..."
    sudo systemctl stop monad-bft monad-execution monad-rpc

    print_info "Running reset-workspace..."
    if [ -f /opt/monad/scripts/reset-workspace.sh ]; then
        bash /opt/monad/scripts/reset-workspace.sh
    else
        print_warn "reset-workspace.sh not found, manual cleanup..."
        sudo rm -rf /home/monad/monad-bft/wal/*
        sudo rm -rf /home/monad/monad-bft/ledger/*
        sudo rm -f /home/monad/monad-bft/statesync.sock
        sudo rm -f /home/monad/monad-bft/mempool.sock
        sudo rm -f /home/monad/monad-bft/controlpanel.sock
    fi

    print_info "Restoring from snapshot (this may take a while)..."
    curl -sSL "$MF_BUCKET/scripts/${net}/restore-from-snapshot.sh" | bash

    print_info "Downloading forkpoint..."
    curl -sSL "$MF_BUCKET/scripts/${net}/download-forkpoint.sh" | bash

    print_info "Updating validators..."
    curl -s "$MF_BUCKET/validators/${net}/validators.toml" -o /home/monad/monad-bft/config/validators/validators.toml
    chown monad:monad /home/monad/monad-bft/config/validators/validators.toml

    print_info "Starting services..."
    sudo systemctl start monad-execution
    sleep 10
    sudo systemctl start monad-bft
    sleep 5
    sudo systemctl start monad-rpc

    sleep 15
    print_info "Checking status..."
    for svc in monad-bft monad-execution monad-rpc; do
        local status
        status=$(systemctl is-active "$svc" 2>/dev/null)
        if [ "$status" = "active" ]; then
            print_success "$svc: active"
        else
            print_error "$svc: $status"
        fi
    done

    press_enter
}

# 10. Swap Management
swap_management() {
    print_banner
    echo -e "${BOLD}⬡ Swap Management${NC}"
    print_separator

    echo -e "\n${BOLD}Current Status:${NC}"
    free -h | grep Swap
    echo -e "  Swappiness: $(cat /proc/sys/vm/swappiness)"

    echo ""
    echo -e "  ${GREEN}1)${NC} Clear swap now (swapoff -a && swapon -a)"
    echo -e "  ${GREEN}2)${NC} Set swappiness to 1"
    echo -e "  ${GREEN}3)${NC} Check swap monitor cron"
    echo -e "  ${RED}0)${NC} Back"
    print_separator
    echo ""
    read -rp "$(echo -e ${CYAN}'Enter choice: '${NC})" choice

    case $choice in
        1)
            print_info "Clearing swap..."
            sudo swapoff -a && sudo swapon -a
            print_success "Swap cleared"
            free -h | grep Swap
            ;;
        2)
            echo 1 | sudo tee /proc/sys/vm/swappiness > /dev/null
            if ! grep -q "vm.swappiness=1" /etc/sysctl.conf 2>/dev/null; then
                echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf > /dev/null
            fi
            sudo sysctl -p > /dev/null 2>&1
            print_success "Swappiness set to 1"
            ;;
        3)
            echo -e "\n${BOLD}Cron jobs:${NC}"
            crontab -l 2>/dev/null | grep swap || echo "  No swap monitor cron found"
            ;;
        0) return ;;
    esac

    press_enter
}

# 11. Environment Check
env_check() {
    print_banner
    echo -e "${BOLD}⬡ Environment Check${NC}"
    print_separator

    echo -e "\n${BOLD}Monad .env:${NC}"
    if [ -f /home/monad/.env ]; then
        cat /home/monad/.env | grep -v "PASSWORD\|KEY" | sed 's/^/  /'
        echo -e "  KEYSTORE_PASSWORD: ${GREEN}[set]${NC}"
    else
        print_error "/home/monad/.env not found"
    fi

    echo -e "\n${BOLD}Node Config:${NC}"
    if [ -f /home/monad/monad-bft/config/node.toml ]; then
        grep -iE "beneficiary|node_name|listen" /home/monad/monad-bft/config/node.toml 2>/dev/null | sed 's/^/  /'
    fi

    echo -e "\n${BOLD}Binary Versions:${NC}"
    local bft_ver exec_ver rpc_ver
    bft_ver=$(journalctl -u monad-bft -n 50 --no-pager 2>/dev/null | grep -oP "version \K[0-9.]+" | tail -1)
    exec_ver=$(journalctl -u monad-execution -n 50 --no-pager 2>/dev/null | grep -oP "commit '\K[^']+" | tail -1)
    rpc_ver=$(journalctl -u monad-rpc -n 50 --no-pager 2>/dev/null | grep -oP "version \K[0-9.]+" | tail -1)
    echo -e "  monad-execution: ${exec_ver:-N/A}"
    echo -e "  monad-rpc: ${rpc_ver:-N/A}"

    echo -e "\n${BOLD}System:${NC}"
    echo -e "  Hostname: $(hostname)"
    echo -e "  OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
    echo -e "  Kernel: $(uname -r)"
    echo -e "  CPU: $(nproc) cores"
    echo -e "  RAM: $(free -h | awk '/Mem:/{print $2}')"

    press_enter
}

# ============================================================
# MAIN MENU
# ============================================================

main_menu() {
    while true; do
        print_banner
        echo -e " ${BOLD}Network: ${CYAN}${NETWORK}${NC} | ${BOLD}RPC: ${CYAN}${LOCAL_RPC}${NC}"
        print_separator
        echo -e "  ${GREEN} 1)${NC}  Quick Status Check"
        echo -e "  ${GREEN} 2)${NC}  Sync Verification"
        echo -e "  ${GREEN} 3)${NC}  Service Status (detailed)"
        echo -e "  ${GREEN} 4)${NC}  View Logs"
        echo -e "  ${GREEN} 5)${NC}  Resource Monitor"
        echo -e "  ${GREEN} 6)${NC}  Wallet Balance"
        echo -e "  ${GREEN} 7)${NC}  Restart Services"
        echo -e "  ${YELLOW} 8)${NC}  Soft Reset"
        echo -e "  ${RED} 9)${NC}  Hard Reset"
        echo -e "  ${GREEN}10)${NC}  Swap Management"
        echo -e "  ${GREEN}11)${NC}  Environment Check"
        print_separator
        echo -e "  ${PURPLE} s)${NC}  Switch Network"
        echo -e "  ${RED} 0)${NC}  Exit"
        print_separator
        echo ""
        read -rp "$(echo -e ${CYAN}'Enter choice: '${NC})" choice

        case $choice in
            1)  quick_status ;;
            2)  sync_check ;;
            3)  service_status ;;
            4)  view_logs ;;
            5)  resource_monitor ;;
            6)  wallet_balance ;;
            7)  restart_services ;;
            8)  soft_reset ;;
            9)  hard_reset ;;
            10) swap_management ;;
            11) env_check ;;
            s|S) select_network ;;
            0)
                echo -e "\n${GREEN}Goodbye! Happy validating! ⬡${NC}\n"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# ============================================================
# ENTRY POINT
# ============================================================

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    print_warn "Some features require root. Run with: sudo bash monad-tool.sh"
fi

select_network
main_menu
