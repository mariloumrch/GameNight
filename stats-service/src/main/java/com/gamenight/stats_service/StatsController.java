package com.gamenight.stats_service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/stats")
public class StatsController {

    @Autowired
    private RestTemplate restTemplate;

    @GetMapping("/{partyId}")
    @CircuitBreaker(name = "playerService", fallbackMethod = "fallbackStats")
    @Retry(name = "playerService")
    public ResponseEntity<PartyStats> getStats(@PathVariable Long partyId) {
        // 1. R\u00e9cup\u00e9rer les infos de la party (via Eureka : nom logique du service)
        PartyDto party = restTemplate.getForObject(
                "http://party-service/parties/" + partyId,
                PartyDto.class);

        // 2. R\u00e9cup\u00e9rer la liste des joueurs
        List<Map<String, Object>> players = restTemplate.getForObject(
                "http://player-service/players/party/" + partyId,
                List.class);

        int playersCount = (players == null) ? 0 : players.size();
        String partyName = (party == null) ? "Unknown" : party.getName();
        String gameType = (party == null) ? "Unknown" : party.getGameType();

        return ResponseEntity.ok(new PartyStats(partyName, gameType, playersCount));
    }

    // Fallback : appel\u00e9 si playerService est indisponible
    public ResponseEntity<PartyStats> fallbackStats(Long partyId, Throwable t) {
        // Essayer de r\u00e9cup\u00e9rer la party quand m\u00eame
        String partyName = "Unknown";
        String gameType = "Unknown";
        try {
            PartyDto party = restTemplate.getForObject(
                    "http://party-service/parties/" + partyId,
                    PartyDto.class);
            if (party != null) {
                partyName = party.getName();
                gameType = party.getGameType();
            }
        } catch (Exception ignored) {}

        return ResponseEntity.ok(new PartyStats(partyName, gameType, -1));
    }
}
