#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# setup-proxmox.sh
# Provisioning script for Proxmox VM deployment
# Creates SSH user, installs Docker, deploys the CTF lab
# ═══════════════════════════════════════════════════════════════

set -e

echo "═══════════════════════════════════════════════════"
echo "  CTF Lab - Admin Feedback System Setup"
echo "  Proxmox VM Provisioning Script"
echo "═══════════════════════════════════════════════════"

# ─── Variables ───
CTF_USER="analyst"
CTF_PASS="blue_team_rocks"
PROJECT_DIR="/opt/ctf-lab"

# ─── Create CTF user with SSH access ───
echo "[1/5] Creating CTF user..."
if ! id "$CTF_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$CTF_USER"
    echo "${CTF_USER}:${CTF_PASS}" | chpasswd
    usermod -aG docker "$CTF_USER" 2>/dev/null || true
    echo "[+] User '$CTF_USER' created with password '$CTF_PASS'"
else
    echo "[~] User '$CTF_USER' already exists"
fi

# ─── Install Docker if not present ───
echo "[2/5] Checking Docker installation..."
if ! command -v docker &>/dev/null; then
    echo "[*] Installing Docker..."
    apt-get update -qq
    apt-get install -y -qq docker.io docker-compose curl git
    systemctl enable docker
    systemctl start docker
    echo "[+] Docker installed"
else
    echo "[~] Docker already installed"
fi

# ─── Clone/Copy project ───
echo "[3/5] Setting up project directory..."
mkdir -p "$PROJECT_DIR"
if [ -d "/tmp/ctf-lab" ]; then
    cp -r /tmp/ctf-lab/* "$PROJECT_DIR/"
else
    echo "[!] Place project files in /tmp/ctf-lab or clone from git"
    echo "    git clone <repo-url> $PROJECT_DIR"
fi

# ─── Build and deploy ───
echo "[4/5] Building and deploying containers..."
cd "$PROJECT_DIR"
docker-compose down 2>/dev/null || true
docker-compose up -d --build

# ─── Wait for services and inject logs ───
echo "[5/5] Waiting for services to start..."
sleep 5

# Verify deployment
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Deployment Complete!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  Web App:     http://$(hostname -I | awk '{print $1}'):3075"
echo "  SSH Access:  ssh -p 2275 analyst@$(hostname -I | awk '{print $1}')"
echo "  SSH Pass:    blue_team_rocks"
echo "  Logs Dir:    /opt/admin/logs/"
echo ""
echo "  Containers:"
docker-compose ps
echo ""
echo "═══════════════════════════════════════════════════"
