#!/bin/bash
# VM 1: MySQL + Site
# Rode na mesma pasta do banco.sql. O docker-compose.yml é criado por este script.
set -e
cd "$(dirname "$0")"

echo "== Instalando Docker, Git e Docker Compose =="
sudo apt update
sudo apt install -y docker.io git
sudo systemctl enable --now docker
sudo curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "== Preparando o disco extra em /Monfire =="
sudo mkdir -p /Monfire
sudo blkid /dev/nvme1n1 || sudo mkfs.ext4 /dev/nvme1n1
sudo mount /dev/nvme1n1 /Monfire || true
grep -q Monfire /etc/fstab || echo "/dev/nvme1n1 /Monfire ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo mkdir -p /Monfire/mysql

echo "== Baixando o site =="
[ -d web-data-viz ] || git clone https://github.com/MonFire-2026/web-data-viz.git

echo "== Criando o .env do site =="
cat > web-data-viz/.env << 'EOF'
AMBIENTE_PROCESSO=producao
APP_PORT=80
APP_HOST=localhost
DB_HOST=localhost
DB_DATABASE=MonFire
DB_USER=adm_monfire
DB_PASSWORD=Monfire@2026
DB_PORT=3306
EOF
cp web-data-viz/.env web-data-viz/.env.dev

cat > web-data-viz/Dockerfile << 'EOF'
FROM node:22-slim
WORKDIR /app
COPY package*.json ./
RUN npm i
COPY . .
CMD ["npm", "start"]
EOF

echo "== Criando o docker-compose.yml =="
cat > docker-compose.yml << 'EOF'
services:
  banco:
    image: mysql:8.0
    container_name: ContainerBD
    restart: unless-stopped
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_ROOT_PASSWORD: urubu100
      MYSQL_DATABASE: MonFire
      MYSQL_USER: adm_monfire
      MYSQL_PASSWORD: Monfire@2026
    ports:
      - "3306:3306"
    volumes:
      - /Monfire/mysql:/var/lib/mysql
      - ./banco.sql:/docker-entrypoint-initdb.d/banco.sql

  site:
    build: ./web-data-viz
    container_name: ctr-site
    restart: unless-stopped
    depends_on:
      - banco
    network_mode: host
EOF

echo "== Subindo os containers =="
sudo docker-compose up -d --build
sudo docker-compose ps

echo "== Pronto! IP privado desta VM (use na VM 2): $(hostname -I | awk '{print $1}') =="