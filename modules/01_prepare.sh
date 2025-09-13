#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../libs/common.sh"

PACKAGES=(curl ufw jq acl fail2ban)
UFW_TCP_PORTS=(22 80 443 3478 5349)
UFW_UDP_PORTS=(3478 5349 49152:65535)
MATRIX_DIRS=(synapse coturn postgres element nginx)
MIN_FREE_KB=$((5*1024*1024))

install_packages() {
    log "Updating package index and installing required packages"
    apt-get update
    apt-get install -y "${PACKAGES[@]}"
}

configure_firewall() {
    log "Configuring UFW"
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    for port in "${UFW_TCP_PORTS[@]}"; do
        ufw allow "${port}/tcp"
    done
    for port in "${UFW_UDP_PORTS[@]}"; do
        ufw allow "${port}/udp"
    done
    ufw --force enable
}

configure_fail2ban() {
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
}

ensure_acl() {
    log "Ensuring ACL support on root filesystem"
    if ! mount | grep ' on / ' | grep -q acl; then
        if [ -w /etc/fstab ]; then
            awk '$2=="/"{if($4=="defaults"){$4="defaults,acl"}else{$4=$4",acl"}}1' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab
        fi
        mount -o remount,acl / || log "Remount with ACL failed"
    fi
}

check_system_info() {
    log "Hostname: $(hostname)"
    log "Timezone: $(timedatectl show -p Timezone --value)"
    FREE_KB=$(df --output=avail / | tail -n1)
    log "Free disk space: $((FREE_KB/1024)) MB"
    if [ "$FREE_KB" -lt "$MIN_FREE_KB" ]; then
        log "Insufficient disk space" >&2
        exit 1
    fi
}

setup_matrix_user() {
    log "Creating user matrix and project directories"
    if ! id -u matrix >/dev/null 2>&1; then
        useradd -m matrix
    fi
    install -o matrix -g matrix -d /opt/matrix
    for d in "${MATRIX_DIRS[@]}"; do
        install -o matrix -g matrix -d "/opt/matrix/$d"
    done
}

main() {
    install_packages
    configure_firewall
    configure_fail2ban
    ensure_acl
    check_system_info
    setup_matrix_user
}

main "$@"
