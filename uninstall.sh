#!/usr/bin/env bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root (sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}   ____    _    __________       _____    _    ______  __                  ${NC}"
echo -e "${GREEN}  / ___/  / \  / ____/ ___|     | ____|  / \  / ___\ \/ /                  ${NC}"
echo -e "${GREEN} / /  _  / _ \| |    \___ \_____|  _|   / _ \ \___ \\  /                   ${NC}"
echo -e "${GREEN}/ /_| |/ ___ \ |___  ___) |_____| |___ / ___ \ ___) /  \                   ${NC}"
echo -e "${GREEN}\____/_/   \_\____|_|____/      |_____/_/   \_\____/_/\_\                  ${NC}"
echo -e "${GREEN}====================== GACS-EASY GenieACS Uninstaller ======================${NC}"

echo -e "${GREEN}============================================================================${NC}"
echo -e "${RED}   This will REMOVE GenieACS, MongoDB (with DB data), Node.js, and Nginx.   ${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${YELLOW}Do you really want to continue? (y/n)${NC}"
read confirmation

if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Uninstallation cancelled. No changes were made.${NC}"
    exit 1
fi

echo -e "${YELLOW}Dropping GenieACS MongoDB database...${NC}"
if command -v mongo >/dev/null 2>&1; then
    mongo genieacs --eval "db.dropDatabase()" || true
elif command -v mongosh >/dev/null 2>&1; then
    mongosh genieacs --eval "db.dropDatabase()" || true
else
    echo -e "${RED}Mongo client not found, skipping DB drop.${NC}"
fi

echo -e "${YELLOW}Stopping services...${NC}"
systemctl stop genieacs-{cwmp,nbi,fs,ui} mongod nginx 2>/dev/null || true
systemctl disable genieacs-{cwmp,nbi,fs,ui} mongod nginx 2>/dev/null || true

echo -e "${YELLOW}Removing GenieACS...${NC}"
npm uninstall -g genieacs || true

echo -e "${YELLOW}Removing MongoDB...${NC}"
apt-get purge -y mongodb-org* percona-server-mongodb* || true

echo -e "${YELLOW}Removing Nginx (if installed)...${NC}"
apt-get purge -y nginx || true

echo -e "${YELLOW}Removing Node.js (if you want to keep Node.js, skip this)...${NC}"
read -p "Remove Node.js? (y/n) [n]: " remove_nodejs
remove_nodejs=$(echo "${remove_nodejs:-n}" | tr '[:upper:]' '[:lower:]')
[[ "$remove_nodejs" == "y" ]] && apt-get purge -y nodejs || echo "Keeping Node.js installed."

apt-get autoremove -y
apt-get clean

echo -e "${YELLOW}Removing MongoDB data and logs...${NC}"
rm -rf /var/lib/mongodb \
       /var/log/mongodb

echo -e "${YELLOW}Removing GenieACS files and configs...${NC}"
rm -rf /opt/genieacs \
       /var/log/genieacs \
       /etc/systemd/system/genieacs-*.service \
       /etc/logrotate.d/genieacs

echo -e "${YELLOW}Removing Nginx configs...${NC}"
rm -f /etc/nginx/sites-available/genieacs \
      /etc/nginx/sites-enabled/genieacs

echo -e "${YELLOW}Removing MongoDB configs...${NC}"
rm -f /etc/apt/sources.list.d/mongodb-org-*.list \
      /usr/share/keyrings/mongodb-server-*.gpg

echo -e "${YELLOW}Removing GenieACS user...${NC}"
userdel genieacs 2>/dev/null || true

systemctl daemon-reload

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN} GenieACS uninstallation completed!${NC}"
echo -e "${GREEN} - GenieACS: Removed${NC}"
echo -e "${GREEN} - MongoDB: Removed (including database)${NC}"
echo -e "${GREEN} - Nginx: Removed (if installed)${NC}"
[[ "$remove_nodejs" == "y" ]] && echo -e "${GREEN} - Node.js: Removed${NC}" || echo -e "${YELLOW} - Node.js: Kept installed${NC}"
echo -e "${GREEN}============================================================================${NC}"
