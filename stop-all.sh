#!/bin/bash

# Arrete tous les services GameNight
# Usage: ./stop-all.sh

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}Arret des services Java...${NC}"
for port in 8761 8082 8083 8084; do
    pid=$(lsof -ti :$port || true)
    if [ -n "$pid" ]; then
        kill -9 $pid 2>/dev/null && echo -e "${GREEN}Tue le process sur :$port${NC}"
    fi
done

echo -e "${YELLOW}Arret de Prometheus et Grafana...${NC}"
docker stop prometheus grafana 2>/dev/null || true

echo -e "${GREEN}Tous les services sont arretes.${NC}"
