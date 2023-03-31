package com.zemasterkrom.vglloadbalancer.configuration.cache;


import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;

import java.util.concurrent.TimeUnit;

/**
 * Caffeine cache bean
 */
public class CacheInstance {

    /**
     * Caffeine cache
     */
    private final Cache<Object,Object> cache;

    /**
     * Constructor of the Caffeine cache
     *
     * @param expireAfterAccess Expiration time after access (in ms)
     * @param expireAfterWrite Expiration time after write (in ms)
     * @param maximumSize Maximum size (entries) of the cache
     */
    public CacheInstance(Long expireAfterAccess, Long expireAfterWrite, Long maximumSize) {
        this.cache = Caffeine.newBuilder().
                expireAfterAccess(expireAfterAccess > 0 ? expireAfterAccess : 1440, TimeUnit.SECONDS).
                expireAfterWrite(expireAfterWrite > 0 ? expireAfterWrite : 1440, TimeUnit.SECONDS).
                maximumSize(maximumSize > 0 ? maximumSize : 60).build();
    }

    public void put(Object key, Object value) {
        this.cache.put(key, value);
    }

    public Object get(Object key) {
        return this.cache.getIfPresent(key);
    }
}
