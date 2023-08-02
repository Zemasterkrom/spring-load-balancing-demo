package com.zemasterkrom.lddiscovery.configuration.health;

import org.springframework.boot.actuate.endpoint.annotation.Endpoint;
import org.springframework.boot.actuate.endpoint.annotation.ReadOperation;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Assigns a random UUID to the Eureka server at startup (accessible through /actuator/uuid).
 * Allows Eureka clients to detect Eureka server crashes.
 */
@Endpoint(id = "uuid")
@Component
public class EurekaServerUuidInformation {
    private final String uuid = UUID.randomUUID().toString();

    @ReadOperation
    public String getUuid() {
        return this.uuid;
    }
}
