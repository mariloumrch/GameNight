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
        // 1. Recuperer la party
        PartyDto party = restTemplate.getForObject(
                "http://party-service/parties/" + partyId,
                PartyDto.class);

        // 2. Recuperer les joueurs (c est ici que ca peut planter)
        List<Map<String, Object>> players = restTemplate.getForObject(
                "http://player-service/players/party/" + partyId,
                List.class);

        int playersCount = (players == null) ? 0 : players.size();
        String partyName = (party == null) ? "Unknown" : party.getName();
        String gameType = (party == null) ? "Unknown" : party.getGameType();

        return ResponseEntity.ok(new PartyStats(partyName, gameType, playersCount));
    }

    // Fallback : doit avoir EXACTEMENT les memes parametres + Throwable a la fin
    public ResponseEntity<PartyStats> fallbackStats(Long partyId, Throwable t) {
        System.err.println("FALLBACK declenche pour partyId=" + partyId + " : " + t.getMessage());

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
        } catch (Exception e) {
            System.err.println("Party aussi indisponible : " + e.getMessage());
        }

        return ResponseEntity.ok(new PartyStats(partyName, gameType, -1));
    }
}
