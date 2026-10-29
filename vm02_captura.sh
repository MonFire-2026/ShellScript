#!/bin/bash
# VM 2: Python (captura) + Java (rede)
# Uso: ./vm2_captura_java.sh <IP_PRIVADO_DA_VM1>
# O docker-compose.yml é criado por este script.
set -e
cd "$(dirname "$0")"
PASTA=$(pwd)
IP_VM1=${1:?Uso: ./vm2_captura_java.sh <IP_PRIVADO_DA_VM1>}

echo "== Instalando Docker, Git, Maven, Java e Docker Compose =="
sudo apt update
sudo apt install -y docker.io git maven openjdk-25-jdk
sudo systemctl enable --now docker
sudo curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "== Preparando o volume extra em /Monfire =="
sudo mkdir -p /Monfire
sudo blkid /dev/nvme1n1 || sudo mkfs.ext4 /dev/nvme1n1
sudo mount /dev/nvme1n1 /Monfire || true
grep -q Monfire /etc/fstab || echo "/dev/nvme1n1 /Monfire ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo mkdir -p /Monfire/java /Monfire/python
sudo chown -R $USER:$USER /Monfire/java /Monfire/python

echo "== Baixando os projetos =="
[ -d Java ]   || git clone https://github.com/MonFire-2026/Java.git
[ -d Python ] || git clone https://github.com/MonFire-2026/Python.git

echo "== Compilando o Java =="
(
  cd "$(dirname "$(find "$PASTA/Java/Captura_oficial" -name pom.xml | head -n 1)")"
  mvn clean package -DskipTests
  cp "$(find target -name '*.jar' ! -name 'original-*' | head -n 1)" /Monfire/java/app.jar
)

echo "== Preparando o Python =="
cat > Python/Dockerfile << 'EOF'
FROM python:3.10-slim
WORKDIR /app
COPY . .
RUN pip install cryptography mysql-connector-python psutil rich
EOF
PY=$(cd Python && find . -name captura.py | head -n 1)

echo "== Criando o docker-compose.yml =="
cat > docker-compose.yml << EOF
services:
  java:
    image: eclipse-temurin:25-jdk
    container_name: ctr-java
    restart: unless-stopped
    network_mode: host
    command: java -jar /dados/app.jar
    volumes:
      - /Monfire/java:/dados
    environment:
      DB_HOST: $IP_VM1
      DB_NAME: MonFire
      DB_USER: adm_monfire
      DB_PASS: Monfire@2026

  python:
    build: ./Python
    container_name: ctr-python
    restart: unless-stopped
    tty: true
    stdin_open: true
    network_mode: host
    command: python $PY
    volumes:
      - /Monfire/python:/dados
      - /:/host:ro
    environment:
      DB_HOST: $IP_VM1
      DB_NAME: MonFire
      DB_USER: adm_monfire
      DB_PASS: Monfire@2026
EOF

echo "== Subindo os containers =="
sudo docker-compose up -d --build
sudo docker-compose ps