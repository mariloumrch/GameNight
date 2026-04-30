package com.gamenight.party_service;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@EnableDiscoveryClient
@SpringBootApplication
public class PartyServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(PartyServiceApplication.class, args);
    }
}
