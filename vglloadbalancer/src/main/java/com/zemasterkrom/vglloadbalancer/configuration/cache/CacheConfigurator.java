package com.zemasterkrom.vglloadbalancer.configuration.cache;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Cache bean instantiator
 */
@Configuration
@ConfigurationProperties(prefix = "spring.cloud.gateway.single-cache")
public class CacheConfigurator {

    /**
     * Expiration time after access (in ms)
     */
    private Long expireAfterAccess = 1440L;

    /**
     * Expiration time after write (in ms)
     */
    private Long expireAfterWrite = 1440L;

    /**
     * Maximum entries in the cache
     */
    private Long maximumSize = 60L;

    public Long getExpireAfterAccess() {
        return expireAfterAccess;
    }

    public void setExpireAfterAccess(Long expireAfterAccess) {
        this.expireAfterAccess = expireAfterAccess;
    }

    public Long getExpireAfterWrite() {
        return expireAfterWrite;
    }

    public void setExpireAfterWrite(Long expireAfterWrite) {
        this.expireAfterWrite = expireAfterWrite;
    }

    public Long getMaximumSize() {
        return maximumSize;
    }

    public void setMaximumSize(Long maximumSize) {
        this.maximumSize = maximumSize;
    }

    @Bean
    public CacheInstance cacheInstance() {
        return new CacheInstance(expireAfterAccess, expireAfterWrite, maximumSize);
    }
}
