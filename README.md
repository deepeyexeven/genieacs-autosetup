# GenieACS Automated Installer

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu)](https://ubuntu.com/)
[![GenieACS](https://img.shields.io/badge/GenieACS-v1.2.13-00A98F)](https://genieacs.com/)
[![Node.js](https://img.shields.io/badge/Node.js-v20.x-339933?logo=node.js)](https://nodejs.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-v4.4-47A248?logo=mongodb)](https://www.mongodb.com/)

A streamlined, one-command installation script for deploying **GenieACS** (Generic Autonomous Customer Premises Equipment Server) on Ubuntu servers. Automates the complete setup of GenieACS with MongoDB, Node.js, systemd services, and firewall configuration.

## ✨ Features

- 🚀 **One-Command Installation** - Complete setup in minutes
- 📦 **Automatic Dependency Management** - Node.js 20.x and MongoDB 4.4 installed automatically
- 🎯 **Service Selection** - Choose which services to enable (UI, CWMP, NBI, FS)
- ⚙️ **Systemd Integration** - Auto-configured services with binary path detection
- 🔒 **Firewall Setup** - UFW rules configured automatically
- 💾 **Parameter Restoration** - Default configurations applied automatically
- 📊 **Disk Space Validation** - Pre-installation space check
- 💻 **Wide Compatibility** - Supports Ubuntu 20.04, 22.04, and 24.04
- 🛡️ **Production Ready** - Optimized for stability and performance

## 📋 System Requirements

| Requirement | Specification |
|------------|---------------|
| **Operating System** | Ubuntu 24.04 LTS |
| **Privileges** | Root or sudo access |
| **Disk Space** | Minimum 2 GB available |
| **RAM** | Recommended 2 GB or more |
| **Network** | Active internet connection |
| **Architecture** | x64 (amd64) or ARM64 |

## 🔧 GenieACS Services

| Service | Port | Status | Description |
|---------|------|--------|-------------|
| **UI** | 3000 | Required | Web-based management interface for device configuration |
| **CWMP** | 7547 | Default: ✅ | TR-069/CWMP protocol server for CPE communication |
| **NBI** | 7557 | Default: ❌ | Northbound REST API for external system integration |
| **FS** | 7567 | Default: ✅ | File server for firmware downloads and provisioning scripts |

> **Default Credentials**: Username: `admin` | Password: `admin`  
> ⚠️ **Change these immediately after first login!**

## 📦 Installation

### Quick Start

```bash
chmod +x install.sh
sudo ./install.sh
```

### Installation Steps

The installer will guide you through:

1. **Confirmation Prompt** - Review and confirm installation
2. **Service Selection** - Choose which services to enable
3. **Automated Setup**:
   - ✓ Disk space validation (minimum 2 GB)
   - ✓ Node.js 20.x installation
   - ✓ MongoDB 4.4 installation (with Ubuntu 24.04 compatibility)
   - ✓ GenieACS 1.2.13 installation
   - ✓ System user and directory creation
   - ✓ Systemd service configuration
   - ✓ Default parameters restoration
   - ✓ UFW firewall configuration
   - ✓ Service health checks

### Installa & Login

Once installation is complete, access the web interface:

```
http://YOUR_SERVER_IP:3000
```

**Login Credentials:**
```
Username: admin
Password: admin
```

> 🔐 **Security Best Practice**: Change the default password immediately after first login through the UI settings.

## 🔥 Firewall Configuration

The installer automatically configures UFW with the following rules:

| Port | Service | Auto-Configured |
|------|---------|----------------|
| 22 | SSH | Always |
| 3000 | GenieACS UI | Always |
| 7547 | CWMP | If enabled |
| 7557 | NBI | If enabled |
| 7567 | FS | If enabled |
- Port 3000 (GenieACS UI)
- Port 7547 (CWMP - if enabled)
- Port 7557 (NBI - if enabled)
- Port 7567 (FS - if enabled)
📂 /opt/genieacs/
 ├── 📂 ext/                      # Custom extension scripts
 └── 📄 genieacs.env              # Environment variables

📂 /var/log/genieacs/
 ├── 📄 genieacs-cwmp-access.log  # CWMP service access log
 ├── 📄 genieacs-nbi-access.log   # NBI service access log
 ├── 📄 genieacs-fs-access.log    # FS service access log
 ├── 📄 genieacs-ui-access.log    # UI service access log
 └── 📄 genieacs-debug.yaml       # Debug information

📂 /etc/systemd/system/
 ├── 📄 genieacs-ui.service       # UI service unit
 ├── 📄 genieacs-cwmp.service     # CWMP service unit
 ├── 📄 genieacs-nbi.service      # NBI service unit
 └── 📄 genieacs-fs.service       # FS service unit

📂 /var/log/
 └── 📄 gacs-install.log          # Installation log
├── genieacs-ui.service
├── genieacs-cwmp.service
├── genieacs-nbi.service
└── genieacs-fs.service
```

## 🛠️ Management Commands

### Service Control

```bash
# Check service status
sudo systemctl status genieacs-ui
sudo systemctl status genieacs-cwmp
sudo systemctl status genieacs-nbi
sudo systemctl status genieacs-fs

# Restart services
sudo systemctl restart genieacs-ui
sudo systemctl restart genieacs-cwmp

# Enable/disable services
sudo systemctl enable genieacs-nbi
sudo systemctl disable genieacs-fs
```

### View Logs

```bash
# Real-time logs
sudo journalctl -u genieacs-ui -f
sudo journalctl -u genieacs-cwmp -f

# Access logs
sudo tail -f /var/log/genieacs/genieacs-ui-access.log
sudo tail -f /var/log/genieacs/genieacs-cwmp-access.log
```

### MongoDB Management

```bash
# Check MongoDB status
sudo systemctl status mongod

# Access MongoDB shell
mongosh
# or for older versions
mongo

# Backup database
mongodump --db genieacs --out /backup/genieacs-backup

# Restore database
mongorestore --db genieacs /backup/genieacs-backup/genieacs
```
### Automated Removal

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```

The uninstaller performs the following actions:
- 🗑️ Drops the GenieACS MongoDB database
- 🛑 Stops and disables all GenieACS services
- 📦 Removes GenieACS package
- 🗄️ Removes MongoDB (with confirmation)
- 🌐 Removes Nginx if installed
- 💾 Prompts for Node.js removal
- 🧹 Cleans configuration files and logs
- 👤 Removes GenieACS, MongoDB, and Nginx (optional)
- Prompt whether to remove Node.js
- Clean up all configuration files and logs
- Remove the GenieACS system user

### Manual Uninstallation

If you prefer to uninstall manually:

```bash
# Stop and disable services
sudo systemctl stop genieacs-ui genieacs-cwmp genieacs-nbi genieacs-fs
sudo systemctl disable genieacs-ui genieacs-cwmp genieacs-nbi genieacs-fs

# Remove service files
sudo rm /etc/systemd/system/genieacs-*.service
sudo systemctl daemon-reload

# Uninstall GenieACS
sudo npm uninstall -g genieacs

# Remove directories
sudo rm -rf /opt/genieacs
sudo rm -rf /var/log/genieacs

# Remove user
sudo userdel genieacs

# (Optional) Remove MongoDB
sudo systemctl stop mongod
sudo apt-get purge -y mongodb-org*
sudo rm -rf /var/lib/mongodb
sudo rm -rf /var/log/mongodb
```

## 🐛 Troub Issues

**Check service status:**
```bash
sudo systemctl status genieacs-ui
sudo systemctl status genieacs-cwmp
```

**View real-time logs:**
```bash
sudo journalctl -u genieacs-ui -f
```

**Restart services:**
```bash
sudo systemctl restart genieacs-ui
```

### MongoDB Issues

**Verify MongoDB is running:**
```bash
sudo systemctl status mongod
```

**Test database connection:**
```bash
mongosh --eval "db.adminCommand('ping')"
```

**Restart MongoDB:**
```bash
sudo systemctl restart mongod
```

### Network/Port Issues

**Check port availability:**
```bash
sudo lsof -i :3000
sudo netstat -tulpn | grep 3000
```

**Verify firewall:**
```bash
sudo ufw status verbose
```
Documentation & Resources

### Official Documentation
- **GenieACS Documentation**: https://docs.genieacs.com/
- **GenieACS GitHub**: https://github.com/genieacs/genieacs
- **TR-069 Protocol Specification**: https://www.broadband-forum.org/technical/download/TR-069.pdf

### Key Concepts
- **ACS** - Auto Configuration Server (GenieACS)
- **CPE** - Customer Premises Equipment (routers, ONTs, etc.)
- **CWMP** - CPE WAN Management Protocol (TR-069)
- **NBI** - Northbound Interface (REST API)

## 🔒 Security Recommendations

1. **Change Default Credentials** immediately after installation
2. **Implement HTTPS** using reverse proxy (Nginx/Apache)
3. **Restrict Access** using firewall rules to trusted IPs
4. **Regular Updates** - Keep system and packages updated
5. **Backup Database** regularly using `mongodump`
6. **Monitor Logs** for suspicious activities

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## 💡 Tips & Notes

- MongoDB 4.4 is used for compatibility with older CPU architectures
- For Ubuntu 24.04, libssl1.1 is automatically installed for MongoDB compatibility
- All services run under a dedicated `genieacs` system user
- Logs are rotated automatically by systemd

---

**Made for GenieACS deployments** • Tested on Ubuntu 24.04 LTS
```bash
sudo ufw allow PORT_NUMBER/tcp
```

## 📚 Resources

- [GenieACS Documentation](https://docs.genieacs.com/)
- [GenieACS GitHub](https://github.com/genieacs/genieacs)
- [TR-069 Protocol](https://www.broadband-forum.org/technical/download/TR-069.pdf)

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: This installer uses MongoDB 4.4 for compatibility with older CPU architectures. If you need a newer version, you can modify the script accordingly.
