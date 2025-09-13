#!/bin/bash
set -e

source "$(dirname "$0")/../libs/common.sh"

PACKAGES=(curl ufw jq acl fail2ban)

log "Updating package index and installing required packages"
apt-get update
apt-get install -y "${PACKAGES[@]}"

log "Configuring UFW"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3478/tcp
ufw allow 3478/udp
ufw allow 5349/tcp
ufw allow 5349/udp
ufw allow 49152:65535/udp
ufw --force enable

log "Configuring fail2ban"
cat >/etc/fail2ban/jail.local <<'JAIL'
[DEFAULT]
bantime = 24h
findtime = 1h
maxretry = 3

[sshd]
enabled = true
logpath = /var/log/auth.log
JAIL
systemctl enable fail2ban
systemctl restart fail2ban

log "Ensuring ACL support on root filesystem"
if ! mount | grep ' on / ' | grep -q acl; then
    if [ -w /etc/fstab ]; then
        awk '$2=="/"{if($4=="defaults"){$4="defaults,acl"}else{$4=$4",acl"}}1' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab
    fi
    mount -o remount,acl / || log "Remount with ACL failed"
fi

log "Hostname: $(hostname)"
log "Timezone: $(timedatectl show -p Timezone --value)"
FREE_KB=$(df --output=avail / | tail -n1)
log "Free disk space: $((FREE_KB/1024)) MB"
if [ "$FREE_KB" -lt $((5*1024*1024)) ]; then
    log "Insufficient disk space" >&2
    exit 1
fi

log "Creating user matrix and project directories"
if ! id -u matrix >/dev/null 2>&1; then
    useradd -m matrix
fi
install -o matrix -g matrix -d /opt/matrix
for d in synapse coturn postgres element nginx; do
    install -o matrix -g matrix -d "/opt/matrix/$d"
done
