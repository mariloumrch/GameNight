package com.gamenight.player_service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/players")
public class PlayerController {

    @Autowired
    private PlayerRepository repository;

    @PostMapping
    public Player create(@RequestBody Player player) {
        return repository.save(player);
    }

    @GetMapping("/party/{partyId}")
    public List<Player> getByPartyId(@PathVariable Long partyId) {
        return repository.findByPartyId(partyId);
    }
}
