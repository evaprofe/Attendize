#!/bin/sh
# =============================================================================
# Preparación de una instancia EC2 Amazon Linux 2023 (Tarea 5).
# Puede pegarse como "User data" al lanzar la instancia o ejecutarse con sudo.
# Instala Docker y el complemento Compose. No guarda ninguna credencial.
# =============================================================================
set -eu
dnf install -y docker git
systemctl enable --now docker
usermod -aG docker ec2-user

# Complemento Docker Compose (no viene en los repositorios de Amazon Linux 2023)
VERSION_COMPOSE="v2.40.3"
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/download/${VERSION_COMPOSE}/docker-compose-linux-$(uname -m)" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

docker --version
docker compose version
