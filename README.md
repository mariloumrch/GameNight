cat > ~/IdeaProjects/GameNight/README.md << 'EOF'
# GameNight - Plateforme Microservices

Plateforme backend pour organiser des soirées de jeux entre amis.
Architecture microservices avec Spring Boot, Eureka, Resilience4j, Prometheus, Grafana et Kubernetes.

## Architecture

Voir le schéma `docs/architecture.png`.

| Service | Port | Rôle |
|---|---|---|
| eureka-server | 8761 | Service Discovery |
| party-service | 8082 | Gestion des soirées (CRUD + H2) |
| player-service | 8083 | Gestion des participants (CRUD + H2) |
| stats-service | 8084 | Agrégation de stats (avec Resilience4j) |
| prometheus | 9090 | Collecte des métriques |
| grafana | 3000 | Visualisation (admin/admin) |

## Prérequis

- Java 17
- Maven (les wrappers `./mvnw` sont fournis)
- Docker (pour Prometheus et Grafana)
- kubectl (pour Kubernetes)

## Lancement rapide

### Tout lancer + tester d'un coup

```bash
./run.sh
```

### Étape par étape

```bash
./start-all.sh   # Build et lance les 4 services Java + Prometheus + Grafana
./test.sh        # Lance la suite de tests (14 tests, dont fallback)
./stop-all.sh    # Arrête tout
```

### Manuel (4 terminaux)

```bash
cd eureka-server && ./mvnw spring-boot:run
cd party-service && ./mvnw spring-boot:run
cd player-service && ./mvnw spring-boot:run
cd stats-service && ./mvnw spring-boot:run
```

## API REST

### Party Service

```bash
curl -X POST http://localhost:8082/parties \
  -H "Content-Type: application/json" \
  -d '{"name":"Poker Night","gameType":"POKER","date":"2026-06-15"}'

curl http://localhost:8082/parties
curl http://localhost:8082/parties/1
```

### Player Service

```bash
curl -X POST http://localhost:8083/players \
  -H "Content-Type: application/json" \
  -d '{"partyId":1,"playerName":"Alice"}'

curl http://localhost:8083/players/party/1
```

### Stats Service

```bash
curl http://localhost:8084/stats/1
# {"partyName":"Poker Night","gameType":"POKER","playersCount":3}
```

## Résilience (Resilience4j)

Le Stats Service est résilient face à l'indisponibilité du Player Service :

- Retry : 3 tentatives avec 500ms entre chaque
- Circuit Breaker : ouverture après 50% d'échecs sur 10 appels
- Fallback : retourne `playersCount: -1`

Test :

```bash
# Arrêter player-service, puis :
curl http://localhost:8084/stats/1
# {"partyName":"Poker Night","gameType":"POKER","playersCount":-1}
```

## Monitoring

Les 3 microservices exposent leurs métriques sur `/actuator/prometheus`.

```bash
curl http://localhost:8082/actuator/prometheus
curl http://localhost:8083/actuator/prometheus
curl http://localhost:8084/actuator/prometheus
```

### Prometheus + Grafana

Lancés automatiquement par `start-all.sh` via Docker.

- Prometheus : http://localhost:9090
- Grafana : http://localhost:3000 (admin / admin)

Le dashboard Grafana affiche :
- Nombre de requêtes HTTP par seconde
- Temps de réponse moyen
- État de santé des services

Métriques utilisées :

```promql
sum(rate(http_server_requests_seconds_count[1m])) by (application)
sum(rate(http_server_requests_seconds_sum[1m])) by (application) / sum(rate(http_server_requests_seconds_count[1m])) by (application)
up
```

## Déploiement Kubernetes

Manifests dans `k8s/`.

```bash
kubectl apply --dry-run=client -f k8s/  # validation
kubectl apply -f k8s/                    # déploiement
kubectl get pods
kubectl get services
```

Accès :

```bash
kubectl port-forward svc/eureka-server 8761:8761
kubectl port-forward svc/grafana 3000:3000
kubectl port-forward svc/prometheus 9090:9090
```

## Tests automatisés

Le script `test.sh` exécute 14 tests :

1. Disponibilité d'Eureka
2. Santé des 3 services
3. Création de soirée
4. Listing des soirées
5. Inscription de 3 joueurs
6. Agrégation des stats
7. Endpoints Prometheus exposés
8. Fallback Resilience4j (arrêt de player-service, vérif `-1`, relance)


## Stack technique

- Java 17 + Spring Boot 3.5
- Spring Cloud 2025.0 (Eureka Client, LoadBalancer)
- Resilience4j 2.2 (Circuit Breaker, Retry)
- Spring Data JPA + H2 (base en mémoire)
- Micrometer + Prometheus + Grafana
- Kubernetes + Docker
  EOF
