#!/bin/bash

# Tests complets de la plateforme GameNight
# Usage: ./test.sh

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ROOT="$(cd "$(dirname "$0")" && pwd)"
PARTY_URL="http://localhost:8082"
PLAYER_URL="http://localhost:8083"
STATS_URL="http://localhost:8084"
EUREKA_URL="http://localhost:8761"

PASS=0
FAIL=0

assert_ok() {
    if [ "$1" = "true" ]; then
        echo -e "${GREEN}  PASS - $2${NC}"
        PASS=$((PASS+1))
    else
        echo -e "${RED}  FAIL - $2${NC}"
        FAIL=$((FAIL+1))
    fi
}

echo -e "${YELLOW}====================================="
echo "  Tests GameNight"
echo -e "=====================================${NC}"

# Test 1 : Eureka UP
echo -e "\n${YELLOW}[1] Verification Eureka${NC}"
if curl -s -f -o /dev/null "$EUREKA_URL"; then
    assert_ok "true" "Eureka repond"
else
    assert_ok "false" "Eureka repond"
    echo -e "${RED}Eureka injoignable, abandon${NC}"
    exit 1
fi

# Test 2 : Sante des 3 services
echo -e "\n${YELLOW}[2] Sante des services${NC}"
for svc in "party:$PARTY_URL" "player:$PLAYER_URL" "stats:$STATS_URL"; do
    name="${svc%%:*}"
    url="${svc#*:}"
    if curl -s "$url/actuator/health" | grep -q '"status":"UP"'; then
        assert_ok "true" "$name-service UP"
    else
        assert_ok "false" "$name-service UP"
    fi
done

# Test 3 : Creation d une soiree
echo -e "\n${YELLOW}[3] Creation d une soiree${NC}"
PARTY=$(curl -s -X POST "$PARTY_URL/parties" \
    -H "Content-Type: application/json" \
    -d '{"name":"Auto Test Night","gameType":"POKER","date":"2026-12-31"}')
PARTY_ID=$(echo "$PARTY" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
if [ -n "$PARTY_ID" ]; then
    assert_ok "true" "Soiree creee (id=$PARTY_ID)"
else
    assert_ok "false" "Soiree creee"
    PARTY_ID=1
fi

# Test 4 : Lister les soirees
echo -e "\n${YELLOW}[4] Liste des soirees${NC}"
LIST=$(curl -s "$PARTY_URL/parties")
if echo "$LIST" | grep -q "Auto Test Night"; then
    assert_ok "true" "Soiree presente dans la liste"
else
    assert_ok "false" "Soiree presente dans la liste"
fi

# Test 5 : Inscription de joueurs
echo -e "\n${YELLOW}[5] Inscription de 3 joueurs${NC}"
for name in "Alice" "Bob" "Charlie"; do
    R=$(curl -s -X POST "$PLAYER_URL/players" \
        -H "Content-Type: application/json" \
        -d "{\"partyId\":$PARTY_ID,\"playerName\":\"$name\"}")
    if echo "$R" | grep -q "$name"; then
        assert_ok "true" "$name inscrit"
    else
        assert_ok "false" "$name inscrit"
    fi
done

# Test 6 : Stats agregees
echo -e "\n${YELLOW}[6] Stats agregees (cas nominal)${NC}"
STATS=$(curl -s "$STATS_URL/stats/$PARTY_ID")
COUNT=$(echo "$STATS" | grep -o '"playersCount":[0-9-]*' | cut -d':' -f2)
if [ "$COUNT" = "3" ]; then
    assert_ok "true" "playersCount = 3"
else
    assert_ok "false" "playersCount = 3 (recu: $COUNT)"
fi

# Test 7 : Endpoints Prometheus
echo -e "\n${YELLOW}[7] Endpoints Prometheus${NC}"
for svc in "party:$PARTY_URL" "player:$PLAYER_URL" "stats:$STATS_URL"; do
    name="${svc%%:*}"
    url="${svc#*:}"
    if curl -s -f -o /dev/null "$url/actuator/prometheus"; then
        assert_ok "true" "$name-service expose /actuator/prometheus"
    else
        assert_ok "false" "$name-service expose /actuator/prometheus"
    fi
done

# Test 8 : FALLBACK
echo -e "\n${YELLOW}[8] Fallback Resilience4j${NC}"
echo "  Arret de player-service..."
PLAYER_PID=$(lsof -ti :8083 2>/dev/null | head -1)

if [ -n "$PLAYER_PID" ]; then
    kill -9 $PLAYER_PID 2>/dev/null
    sleep 5
    
    echo "  Appel stats-service (player-service down)..."
    FALLBACK_STATS=$(curl -s --max-time 15 "$STATS_URL/stats/$PARTY_ID" 2>/dev/null)
    echo "  Reponse: $FALLBACK_STATS"
    FALLBACK_COUNT=$(echo "$FALLBACK_STATS" | grep -o '"playersCount":[0-9-]*' | cut -d':' -f2)
    
    if [ "$FALLBACK_COUNT" = "-1" ]; then
        assert_ok "true" "Fallback declenche (playersCount = -1)"
    else
        assert_ok "false" "Fallback declenche (recu: '$FALLBACK_COUNT')"
    fi
    
    echo "  Relancement de player-service..."
    mkdir -p "$ROOT/logs"
    (cd "$ROOT/player-service" && nohup java -jar target/*.jar > "$ROOT/logs/player-service.log" 2>&1 &)
    
    echo "  Attente du redemarrage (20s)..."
    sleep 20
    
    if curl -s "$PLAYER_URL/actuator/health" 2>/dev/null | grep -q '"status":"UP"'; then
        assert_ok "true" "player-service redemarre"
    else
        assert_ok "false" "player-service redemarre"
    fi
else
    echo -e "${RED}  Impossible de trouver le PID de player-service${NC}"
    FAIL=$((FAIL+1))
fi

# Resume
echo -e "\n${YELLOW}====================================="
echo "  Resultats : $PASS reussis, $FAIL echoues"
echo -e "=====================================${NC}"

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}Tous les tests sont passes !${NC}"
    exit 0
else
    echo -e "${RED}$FAIL test(s) ont echoue${NC}"
    exit 1
fi
