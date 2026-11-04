#!/bin/bash
# VM 2: Python (CPU, RAM e Disco) + Java (Rede)
# Uso: ./vm02_captura.sh <IP_PRIVADO_DA_VM1>
set -euo pipefail

cd "$(dirname "$0")"
PASTA=$(pwd)
IP_VM1=${1:?Uso: ./vm02_captura.sh <IP_PRIVADO_DA_VM1>}
AGENTE_ENV=/Monfire/python/agente.env

DB_PORT=3306
DB_NAME=MonFire
DB_USER=adm_monfire
DB_PASS=Monfire@2026

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
sudo chown -R "$USER:$USER" /Monfire/java /Monfire/python

echo "== Baixando os projetos =="
[ -d Java ] || git clone https://github.com/MonFire-2026/Java.git
[ -d Python ] || git clone https://github.com/MonFire-2026/Python.git

echo "== Compilando o Java =="
(
  cd "$(dirname "$(find "$PASTA/Java/Captura_oficial" -name pom.xml | head -n 1)")"
  mvn clean package -DskipTests
  cp "$(find target -name '*.jar' ! -name 'original-*' | head -n 1)" /Monfire/java/app.jar
)

echo "== Preparando a imagem do Python =="
cat > Python/Dockerfile << 'EOF'
FROM python:3.10-slim
WORKDIR /app
RUN mkdir -p /host/etc
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EOF

PY=$(cd Python && find . -name captura.py | head -n 1)
if [ -z "$PY" ]; then
  echo "captura.py não foi encontrado no projeto Python."
  exit 1
fi

sudo docker build -t monfire-python:latest ./Python

if [ -f "$AGENTE_ENV" ]; then
  echo "== Reutilizando a ativação existente =="
else
  echo "== Ativando a máquina =="
  sudo docker run --rm -it \
    --network host \
    -v /Monfire/python:/dados \
    -v /etc/hostname:/host/etc/hostname:ro \
    -v /etc/os-release:/host/etc/os-release:ro \
    -e "DB_HOST=$IP_VM1" \
    -e "DB_PORT=$DB_PORT" \
    -e "DB_NAME=$DB_NAME" \
    -e "DB_USER=$DB_USER" \
    -e "DB_PASS=$DB_PASS" \
    monfire-python:latest python ativar.py

fi

sudo chown "$USER:$USER" "$AGENTE_ENV"
MAQUINA_ID=$(sed -n 's/^MAQUINA_ID=//p' "$AGENTE_ENV")
if ! [[ "$MAQUINA_ID" =~ ^[1-9][0-9]*$ ]]; then
  echo "O arquivo $AGENTE_ENV não possui um MAQUINA_ID válido."
  exit 1
fi

echo "== Máquina identificada com ID $MAQUINA_ID =="

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
    env_file:
      - /Monfire/python/agente.env
    environment:
      DB_HOST: $IP_VM1
      DB_PORT: $DB_PORT
      DB_NAME: $DB_NAME
      DB_USER: $DB_USER
      DB_PASS: $DB_PASS

  python:
    image: monfire-python:latest
    container_name: ctr-python
    restart: unless-stopped
    network_mode: host
    command: python $PY
    volumes:
      - /:/host:ro
      - /proc:/host/proc:ro
    env_file:
      - /Monfire/python/agente.env
    environment:
      DB_HOST: $IP_VM1
      DB_PORT: $DB_PORT
      DB_NAME: $DB_NAME
      DB_USER: $DB_USER
      DB_PASS: $DB_PASS
EOF

echo "== Subindo os coletores separados =="
sudo docker-compose up -d
sudo docker-compose ps
