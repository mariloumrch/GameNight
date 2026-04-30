#!/bin/bash

# Build et lance tous les services GameNight
# Usage: ./start-all.sh

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

echo -e "${YELLOW}=== Build des services ===${NC}"
for svc in eureka-server party-service player-service stats-service; do
    echo -e "${YELLOW}Build de $svc...${NC}"
    (cd "$ROOT/$svc" && ./mvnw clean package -DskipTests -q)
    echo -e "${GREEN}OK - $svc compile${NC}"
done

echo -e "\n${YELLOW}=== Demarrage des services ===${NC}"

# 1. Eureka d abord (les autres en dependent)
echo -e "${YELLOW}Demarrage Eureka (port 8761)...${NC}"
(cd "$ROOT/eureka-server" && nohup java -jar target/*.jar > "$LOG_DIR/eureka.log" 2>&1 &)
echo "Attente du demarrage d Eureka..."
for i in {1..30}; do
    if curl -s -f -o /dev/null http://localhost:8761; then
        echo -e "${GREEN}OK - Eureka UP${NC}"
        break
    fi
    sleep 1
done

# 2. Les 3 microservices en parallele
for svc in party-service player-service stats-service; do
    echo -e "${YELLOW}Demarrage $svc...${NC}"
    (cd "$ROOT/$svc" && nohup java -jar target/*.jar > "$LOG_DIR/$svc.log" 2>&1 &)
done

echo "Attente du demarrage des services (30s)..."
sleep 30

# 3. Verification
echo -e "\n${YELLOW}=== Verification ===${NC}"
for url in "Eureka:http://localhost:8761" \
           "Party:http://localhost:8082/actuator/health" \
           "Player:http://localhost:8083/actuator/health" \
           "Stats:http://localhost:8084/actuator/health"; do
    name="${url%%:*}"
    target="${url#*:}"
    if curl -s -f -o /dev/null "$target"; then
        echo -e "${GREEN}OK - $name UP${NC}"
    else
        echo -e "${RED}KO - $name DOWN (voir $LOG_DIR/)${NC}"
    fi
done

# 4. Lancer Prometheus et Grafana via Docker
echo -e "\n${YELLOW}=== Demarrage Prometheus + Grafana (Docker) ===${NC}"

if docker ps -a --format '{{.Names}}' | grep -q '^prometheus$'; then
    docker start prometheus > /dev/null
    echo -e "${GREEN}OK - Prometheus redemarre${NC}"
else
    docker run -d --name prometheus \
        -p 9090:9090 \
        -v "$ROOT/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml" \
        prom/prometheus > /dev/null
    echo -e "${GREEN}OK - Prometheus cree${NC}"
fi

if docker ps -a --format '{{.Names}}' | grep -q '^grafana$'; then
    docker start grafana > /dev/null
    echo -e "${GREEN}OK - Grafana redemarre${NC}"
else
    docker run -d --name grafana -p 3000:3000 grafana/grafana > /dev/null
    echo -e "${GREEN}OK - Grafana cree${NC}"
fi

echo -e "\n${GREEN}=== Tout est lance ! ===${NC}"
echo "Eureka     : http://localhost:8761"
echo "Party      : http://localhost:8082"
echo "Player     : http://localhost:8083"
echo "Stats      : http://localhost:8084"
echo "Prometheus : http://localhost:9090"
echo "Grafana    : http://localhost:3000 (admin/admin)"
echo ""
echo "Logs disponibles dans : $LOG_DIR"
echo "Pour tout arreter : ./stop-all.sh"
