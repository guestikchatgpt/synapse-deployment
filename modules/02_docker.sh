#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../libs/common.sh"

install_docker() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        log "Docker and docker compose already installed"
        return
    fi

    log "Installing Docker from official repository"
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    fi
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

configure_user_group() {
    local user=${SUDO_USER:-$USER}
    if id -nG "$user" | grep -qw docker; then
        log "User $user already in docker group"
    else
        log "Adding $user to docker group"
        groupadd -f docker
        usermod -aG docker "$user"
    fi
}

configure_daemon() {
    log "Configuring /etc/docker/daemon.json"
    mkdir -p /etc/docker
    cat >/etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
JSON
    systemctl enable docker
    systemctl restart docker
}

test_docker() {
    log "Testing Docker with hello-world image"
    docker run --rm hello-world
}

ensure_compatibility() {
    log "Ensuring docker-compose compatibility"
    if ! command -v docker-compose >/dev/null 2>&1; then
        cat >/usr/local/bin/docker-compose <<'WRAP'
#!/bin/sh
exec docker compose "$@"
WRAP
        chmod +x /usr/local/bin/docker-compose
    fi
}

main() {
    install_docker
    configure_user_group
    configure_daemon
    test_docker
    ensure_compatibility
}

main "$@"
