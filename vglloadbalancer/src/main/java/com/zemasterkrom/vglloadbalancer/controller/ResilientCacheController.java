package com.zemasterkrom.vglloadbalancer.controller;

import com.zemasterkrom.vglloadbalancer.configuration.CacheInstance;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cloud.gateway.support.ServerWebExchangeUtils;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.server.ServerWebExchange;

import java.net.URI;
import java.util.LinkedHashSet;


/**
 * Video Games Library alternative controller using cache for GET requests
 */
@Controller
public class ResilientCacheController {
    /**
     * Caffeine cache
     */
    private final CacheInstance cache;

    /**
     * Constructor of the resilient cache manager
     *
     * @param c Cache
     */
    @Autowired
    public ResilientCacheController(CacheInstance c) {
        this.cache = c;
    }

    /**
     * Each GET request is forwarded to /vgl-cache if it fails. Instead of accessing the database content, the cache data is used.
     *
     * @param exchange Data exchange
     *
     * @return Cached data if available
     */
    @GetMapping(value = "/vgl-cache", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> getVGLCache(ServerWebExchange exchange) {
        String originalPath = "";
        LinkedHashSet<URI> attr = exchange.getAttribute(ServerWebExchangeUtils.GATEWAY_ORIGINAL_REQUEST_URL_ATTR);

        if (attr != null) {
            originalPath = attr.iterator().hasNext() ? attr.iterator().next().getPath() : "";
        }

        return ResponseEntity.ok(
                this.cache.get(originalPath) != null ?
                        this.cache.get(originalPath).toString() :
                        "{}"
        );
    }
}
