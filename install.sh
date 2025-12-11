#!/usr/bin/env bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG_FILE="/var/log/gacs-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "============================================================================"
echo "GACS-EASY Installation Log - $(date)"
echo "============================================================================"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root (sudo).${NC}"
  exit 1
fi

check_disk_space() {
  REQUIRED_SPACE_MB=$1
  AVAILABLE_SPACE_MB=$(df --output=avail / | tail -n 1)
  AVAILABLE_SPACE_MB=$((AVAILABLE_SPACE_MB / 1024))

  if [ "$AVAILABLE_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
    echo -e "${RED}Error: Not enough disk space on root filesystem.${NC}"
    echo -e "${YELLOW}Available: ${AVAILABLE_SPACE_MB} MB, Required: ${REQUIRED_SPACE_MB} MB${NC}"
    echo -e "${RED}Please free up space before running this installer.${NC}"
    exit 1
  else
    echo -e "${GREEN}Disk space check passed: ${AVAILABLE_SPACE_MB} MB available.${NC}"
  fi
}

check_disk_space 1024

local_ip=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}   ____            _         _    ____ ____    ___           _        _ _            ${NC}"
echo -e "${GREEN}  / ___| ___ _ __ (_) ___   / \  / ___/ ___|  |_ _|_ __  ___| |_ __ _| | | ___ _ __  ${NC}"
echo -e "${GREEN} | |  _ / _ \ '_ \| |/ _ \ / _ \| |   \___ \   | || '_ \/ __| __/ _\` | | |/ _ \ '__| ${NC}"
echo -e "${GREEN} | |_| |  __/ | | | |  __// ___ \ |___ ___) |  | || | | \__ \ || (_| | | |  __/ |    ${NC}"
echo -e "${GREEN}  \____|\___|_| |_|_|\___/_/   \_\____|____/  |___|_| |_|___/\__\__,_|_|_|\___|_|    ${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}                           Author: DeepEyexeven                             ${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}Do you want to continue? (y/n)${NC}"
read confirmation

if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Installation cancelled. No changes were made.${NC}"
    exit 1
fi

echo -e "${YELLOW}Select which GenieACS services to enable:${NC}"

echo -e "  UI (Port 3000, required)"
echo -e "     → Web interface for managing devices and configuration."
echo
echo -e "  CWMP (Port 7547)"
echo -e "     → Handles TR-069 / CWMP communication between ACS and CPE devices."
echo
echo -e "  NBI (Port 7557)"
echo -e "     → REST API for integrating GenieACS with OSS/BSS (external systems)."
echo
echo -e "  FS (Port 7567)"
echo -e "     → File server for firmware, scripts, and provisioning files."
echo

read -p "Enable CWMP? (y/n) [y]: " enable_cwmp
read -p "Enable NBI? (y/n) [n]: " enable_nbi
read -p "Enable FS? (y/n) [y]: " enable_fs

enable_cwmp=$(echo "${enable_cwmp:-y}" | tr '[:upper:]' '[:lower:]')
enable_nbi=$(echo "${enable_nbi:-n}" | tr '[:upper:]' '[:lower:]')
enable_fs=$(echo "${enable_fs:-y}" | tr '[:upper:]' '[:lower:]')

NODE_INSTALLED=false
MONGO_RUNNING=false

if command -v node >/dev/null 2>&1; then
    NODE_INSTALLED=true
fi

if systemctl is-active --quiet mongod; then
    MONGO_RUNNING=true
fi

if ! $NODE_INSTALLED; then
    echo -e "${YELLOW}Installing Node.js 20.x...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
    bash nodesource_setup.sh
    apt-get install -y nodejs
    rm -f nodesource_setup.sh
    echo -e "${GREEN}Node.js $(node -v) installed successfully!${NC}"
else
    echo -e "${GREEN}Node.js $(node -v) is already installed.${NC}"
fi

if ! $MONGO_RUNNING; then
    echo -e "${YELLOW}Cleaning old MongoDB packages (if any)...${NC}"
    systemctl stop mongod 2>/dev/null || true
    apt-get purge -y mongodb-org* percona-server-mongodb* 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/mongodb-org-*.list
    rm -f /usr/share/keyrings/mongodb-server-*.gpg
    apt-get update -qq
    apt-get install -y gnupg curl

    # Detect Ubuntu version
    UBUNTU_VERSION=$(lsb_release -rs)
    echo -e "${YELLOW}Detected Ubuntu $UBUNTU_VERSION${NC}"
# For Ubuntu 24.04, install libssl1.1 manually
        echo -e "${YELLOW}Installing libssl1.1 compatibility library for Ubuntu 24.04...${NC}"
        wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
        dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb || apt-get install -f -y
        rm -f libssl1.1_1.1.1f-1ubuntu2_amd64.deb
    fi

    echo -e "${YELLOW}Installing MongoDB 4.4...${NC}"
    curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | \
       gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg --dearmor

    # MongoDB 4.4 uses focal repository for Ubuntu
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | \
        tee /etc/apt/sources.list.d/mongodb-org-4.4.list

    apt-get update -qq
    apt-get install -y mongodb-org
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}MongoDB installation failed. Check /var/log/gacs-install.log for details${NC}"
        exit 1
    fi
    
    systemctl enable mongod
    systemctl start mongod
    
    # Wait for MongoDB to be ready
    MONGO_READY=false
    for i in {1..30}; do
        if mongosh --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1 || mongo --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
            echo -e "${GREEN}MongoDB is ready!${NC}"
            MONGO_READY=true
            break
        fi
        sleep 1
    done
    
    if [ "$MONGO_READY" = false ]; then
        echo -e "${RED}MongoDB failed to start. Check /var/log/gacs-install.log for details${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}MongoDB is already installed and running.${NC}"
fi

# ------------------------
npm install -g genieacs@1.2.13
useradd --system --no-create-home --user-group genieacs || true

mkdir -p /opt/genieacs/ext
mkdir -p /var/log/genieacs
chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF

chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

# Determine GenieACS binary path
GENIEACS_BIN_PATH=$(which genieacs-ui 2>/dev/null || echo "/usr/local/bin/genieacs-ui")
GENIEACS_BIN_DIR=$(dirname "$GENIEACS_BIN_PATH")
# Create systemd services (but only enable chosen)
for svc in ui cwmp nbi fs; do
    [[ "$svc" == "cwmp" && "$enable_cwmp" != "y" ]] && continue
    [[ "$svc" == "nbi" && "$enable_nbi" != "y" ]] && continue
    [[ "$svc" == "fs" && "$enable_fs" != "y" ]] && continue
    cat << EOF > /etc/systemd/system/genieacs-$svc.service
[Unit]
Description=GenieACS $svc
After=network.target mongod.service

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=$GENIEACS_BIN_DIR/genieacs-$svc
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
done

systemctl daemon-reload
systemctl enable --now genieacs-ui

[[ "$enable_cwmp" == "y" ]] && systemctl enable --now genieacs-cwmp
[[ "$enable_nbi" == "y" ]] && systemctl enable --now genieacs-nbi
[[ "$enable_fs" == "y" ]] && systemctl enable --now genieacs-fs

# ------------------------
PARAM_DIR="/opt/GenieACS-Installer/parameter"

if [ -d "$PARAM_DIR" ] && [ -f "$PARAM_DIR/config.bson" ]; then
    echo -e "${YELLOW}Restoring default GenieACS parameters...${NC}"
    sleep 3  # Wait for services to initialize
    
    mongorestore --db genieacs --collection config --drop "$PARAM_DIR/config.bson" 2>/dev/null
    mongorestore --db genieacs --collection virtualParameters --drop "$PARAM_DIR/virtualParameters.bson" 2>/dev/null
    mongorestore --db genieacs --collection presets --drop "$PARAM_DIR/presets.bson" 2>/dev/null
    mongorestore --db genieacs --collection provisions --drop "$PARAM_DIR/provisions.bson" 2>/dev/null
    
    echo -e "${GREEN}Default parameters restored successfully!${NC}"
    
    echo -e "${YELLOW}Restarting GenieACS services...${NC}"
    systemctl restart genieacs-ui
    [[ "$enable_cwmp" == "y" ]] && systemctl restart genieacs-cwmp
    [[ "$enable_nbi" == "y" ]] && systemctl restart genieacs-nbi
    [[ "$enable_fs" == "y" ]] && systemctl restart genieacs-fs
    sleep 2
else
    echo -e "${YELLOW}Parameter directory not found, skipping restoration${NC}"
fi

# ------------------------
apt-get install -y ufw
ufw allow 22/tcp
ufw allow 3000/tcp
[[ "$enable_cwmp" == "y" ]] && ufw allow 7547/tcp
[[ "$enable_nbi" == "y" ]] && ufw allow 7557/tcp
[[ "$enable_fs" == "y" ]] && ufw allow 7567/tcp
ufw --force enable

# ------------------------
# Service Status Check
# ------------------------
echo -e "${YELLOW}Checking service status...${NC}"

MONGODB_STATUS=$(systemctl is-active mongod)
UI_STATUS=$(systemctl is-active genieacs-ui)
CWMP_STATUS=$(systemctl is-active genieacs-cwmp)
NBI_STATUS=$(systemctl is-active genieacs-nbi)
FS_STATUS=$(systemctl is-active genieacs-fs)

echo "============================================================================" >> "$LOG_FILE"
echo "Service Status Check - $(date)" >> "$LOG_FILE"
echo "============================================================================" >> "$LOG_FILE"
echo "MongoDB (mongod): $MONGODB_STATUS" >> "$LOG_FILE"
echo "GenieACS UI: $UI_STATUS" >> "$LOG_FILE"
[[ "$enable_cwmp" == "y" ]] && echo "GenieACS CWMP: $CWMP_STATUS" >> "$LOG_FILE"
[[ "$enable_nbi" == "y" ]] && echo "GenieACS NBI: $NBI_STATUS" >> "$LOG_FILE"
[[ "$enable_fs" == "y" ]] && echo "GenieACS FS: $FS_STATUS" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Check for any failed services
FAILED_SERVICES=""
[[ "$MONGODB_STATUS" != "active" ]] && FAILED_SERVICES="$FAILED_SERVICES MongoDB"
[[ "$UI_STATUS" != "active" ]] && FAILED_SERVICES="$FAILED_SERVICES UI"
[[ "$enable_cwmp" == "y" ]] && [[ "$CWMP_STATUS" != "active" ]] && FAILED_SERVICES="$FAILED_SERVICES CWMP"
[[ "$enable_nbi" == "y" ]] && [[ "$NBI_STATUS" != "active" ]] && FAILED_SERVICES="$FAILED_SERVICES NBI"
[[ "$enable_fs" == "y" ]] && [[ "$FS_STATUS" != "active" ]] && FAILED_SERVICES="$FAILED_SERVICES FS"

if [[ -n "$FAILED_SERVICES" ]]; then
    echo -e "${RED}WARNING: The following services are not running:$FAILED_SERVICES${NC}"
    echo -e "${YELLOW}Check logs with: journalctl -xe${NC}"
    echo "FAILED SERVICES:$FAILED_SERVICES" >> "$LOG_FILE"
    
    echo "============================================================================" >> "$LOG_FILE"
    echo "Service Logs for Failed Services" >> "$LOG_FILE"
    echo "============================================================================" >> "$LOG_FILE"
    [[ "$enable_nbi" == "y" ]] && [[ "$NBI_STATUS" != "active" ]] && journalctl -u genieacs-nbi -n 50 --no-pager >> "$LOG_FILE" 2>&1
    [[ "$enable_fs" == "y" ]] && [[ "$FS_STATUS" != "active" ]] && journalctl -u genieacs-fs -n 50 --no-pager >> "$LOG_FILE" 2>&1
fi

# ------------------------
echo -e "${GREEN} GenieACS installation completed!${NC}"
echo -e "${GREEN} UI:     http://$local_ip:3000${NC}"
echo -e "${GREEN} USER:   admin${NC}"
echo -e "${GREEN} PASS:   admin${NC}"
[[ "$enable_cwmp" == "y" ]] && echo -e "${GREEN} CWMP:   Port 7547${NC}"
[[ "$enable_nbi" == "y" ]] && echo -e "${GREEN} NBI:    Port 7557${NC}"
[[ "$enable_fs" == "y" ]] && echo -e "${GREEN} FS:     Port 7567${NC}"
echo -e "${GREEN}============================================================================${NC}"
MONGODB_VERSION=$(mongod --version 2>/dev/null | grep "db version" | awk '{print $3}' || echo "installed")
echo -e "${GREEN} MongoDB: $MONGODB_VERSION ($MONGODB_STATUS)${NC}"
echo -e "${GREEN} GenieACS UI: $UI_STATUS${NC}"
[[ "$enable_cwmp" == "y" ]] && echo -e "${GREEN} GenieACS CWMP: $CWMP_STATUS${NC}"
[[ "$enable_fs" == "y" ]] && echo -e "${GREEN} GenieACS FS: $FS_STATUS${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN} Default parameters: Restored from parameter/ folder${NC}"
echo -e "${YELLOW} Installation log saved to: $LOG_FILE${NC}"
echo -e "${GREEN}============================================================================${NC}"

if [[ -n "$FAILED_SERVICES" ]]; then
    echo -e "${RED}⚠ Some services failed to start. Please check the log file:${NC}"
    echo -e "${YELLOW}   cat $LOG_FILE${NC}"
fi
