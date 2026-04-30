#!/bin/bash

# Script complet : build, lance, teste, et arrete tout
# Usage: ./run.sh

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo -e "${YELLOW}╔═══════════════════════════════════════╗"
echo -e "║  GameNight - Pipeline complet         ║"
echo -e "╚═══════════════════════════════════════╝${NC}"

# Cleanup avant
echo -e "\n${YELLOW}[0/3] Nettoyage des anciens processus...${NC}"
"$ROOT/stop-all.sh"
sleep 2

# Build et demarrage
echo -e "\n${YELLOW}[1/3] Build et demarrage des services...${NC}"
"$ROOT/start-all.sh"

# Tests
echo -e "\n${YELLOW}[2/3] Lancement des tests...${NC}"
sleep 5
"$ROOT/test.sh"
TEST_RESULT=$?

# Resume final
echo -e "\n${YELLOW}[3/3] Resume final${NC}"
if [ "$TEST_RESULT" -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════╗"
    echo -e "║   PIPELINE TERMINE AVEC SUCCES        ║"
    echo -e "╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "Services accessibles :"
    echo "  - Eureka     : http://localhost:8761"
    echo "  - Party      : http://localhost:8082/parties"
    echo "  - Player     : http://localhost:8083/players"
    echo "  - Stats      : http://localhost:8084/stats/{id}"
    echo "  - Prometheus : http://localhost:9090"
    echo "  - Grafana    : http://localhost:3000 (admin/admin)"
    echo ""
    echo "Pour arreter tout : ./stop-all.sh"
else
    echo -e "${RED}╔═══════════════════════════════════════╗"
    echo -e "║   CERTAINS TESTS ONT ECHOUE           ║"
    echo -e "╚═══════════════════════════════════════╝${NC}"
fi

exit $TEST_RESULT
