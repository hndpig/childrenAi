package com.pethabit;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@SpringBootApplication
@EnableDiscoveryClient
public class PetHabitApplication {
    public static void main(String[] args) {
        SpringApplication.run(PetHabitApplication.class, args);
    }
}
