package com.gamenight.stats_service;

public class PartyDto {

    private Long id;
    private String name;
    private String gameType;
    private String date;

    public PartyDto() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getGameType() { return gameType; }
    public void setGameType(String gameType) { this.gameType = gameType; }

    public String getDate() { return date; }
    public void setDate(String date) { this.date = date; }
}
