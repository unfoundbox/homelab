#!/usr/bin/env bash

set -euo pipefail

USERNAME="deploy"
TIMEZONE="Asia/Kolkata"

GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

log() {
  echo -e "${BLUE}==>${RESET} $1"
}

success() {
  echo -e "${GREEN}✔ $1${RESET}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${RESET}"
}

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Run as root${RESET}"
  exit 1
fi

log "Updating system..."
apt update
apt upgrade -y

log "Installing packages..."
apt install -y \
  curl wget git unzip zip htop btop tmux jq ncdu tree \
  build-essential software-properties-common apt-transport-https \
  ca-certificates gnupg lsb-release ufw fail2ban openssh-server \
  python3 python3-pip python3-venv \
  postgresql postgresql-contrib redis-server

success "Packages installed"

log "Setting timezone..."
timedatectl set-timezone "$TIMEZONE"

if id "$USERNAME" &>/dev/null; then
  warn "User already exists"
else
  log "Creating deploy user..."

  adduser --disabled-password --gecos "" "$USERNAME"
  usermod -aG sudo "$USERNAME"

  mkdir -p /home/$USERNAME/.ssh
  chmod 700 /home/$USERNAME/.ssh

  echo "Paste your PUBLIC SSH key:"
  read -r SSH_KEY

  echo "$SSH_KEY" > /home/$USERNAME/.ssh/authorized_keys

  chmod 600 /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
fi

log "Configuring SSH safely..."

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

systemctl restart ssh

log "Configuring swap..."

if ! swapon --show | grep -q swapfile; then
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

log "Installing Docker..."

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update

apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

usermod -aG docker "$USERNAME"

log "Installing Node.js..."

curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs
npm install -g pnpm pm2 bun

log "Installing Tailscale..."

curl -fsSL https://tailscale.com/install.sh | sh

log "Installing Caddy..."

apt install -y debian-keyring debian-archive-keyring

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor | tee /usr/share/keyrings/caddy-stable-archive-keyring.gpg >/dev/null
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

apt update
apt install -y caddy

systemctl enable caddy
systemctl start caddy

log "Installing Ollama..."

curl -fsSL https://ollama.com/install.sh | sh

mkdir -p /srv/apps /srv/data /srv/backups /srv/logs /srv/docker
chown -R $USERNAME:$USERNAME /srv

log "Configuring firewall..."

ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

systemctl enable fail2ban
systemctl start fail2ban

log "Installing Open WebUI..."

docker volume create open-webui

docker run -d \
  --name open-webui \
  --restart unless-stopped \
  -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main

log "Installing Uptime Kuma..."

docker volume create uptime-kuma

docker run -d \
  --name uptime-kuma \
  --restart unless-stopped \
  -p 127.0.0.1:3001:3001 \
  -v uptime-kuma:/app/data \
  louislam/uptime-kuma:1

log "Installing Watchtower..."

docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --cleanup \
  --schedule "0 0 4 * * *"

success "Homelab bootstrap complete"

echo
echo "Next steps:"
echo

echo "sudo reboot"
echo "sudo tailscale up"
echo "ollama run gemma3:4b"
