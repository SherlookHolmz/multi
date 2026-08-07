#!/usr/bin/env bash
# Installer for Sherlook Automate Engine
CYAN='\033[1;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

# Point this at wherever you host sherlook.sh (your repo, replacing the old one)
REPO="https://raw.githubusercontent.com/SherlookHolmz/multi/main"

print_status() {
    echo -e "${CYAN}[*]${NC} $1"
}

clear
echo -e "${CYAN}========================================"
echo -e "        Sherlook Engine Installer        "
echo -e "========================================${NC}"

print_status "Updating system packages..."
apt-get update -y > /dev/null 2>&1
print_status "Installing dependencies (tor, curl, jq, openssl, cron)..."
apt-get install -y tor curl jq openssl cron > /dev/null 2>&1

print_status "Downloading Sherlook Engine..."
if curl -fsSL "$REPO/sherlook.sh" -o /usr/local/bin/sherlook; then
    chmod +x /usr/local/bin/sherlook
    echo -e "${GREEN}[+] Installation Complete!${NC}"
else
    echo -e "${RED}[!] Download failed. Please check your internet connection or the REPO URL.${NC}"
    exit 1
fi

echo -e "\n${CYAN}[*] Launching program...${NC}\n"
sleep 1
/usr/local/bin/sherlook
