package com.zemasterkrom.videogameslibraryapplication.configuration.health;

import com.netflix.appinfo.InstanceInfo;
import com.netflix.discovery.shared.resolver.aws.ConfigClusterResolver;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.AutoConfigureAfter;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.cloud.context.scope.refresh.RefreshScope;
import org.springframework.cloud.netflix.eureka.InstanceInfoFactory;
import org.springframework.cloud.netflix.eureka.serviceregistry.EurekaAutoServiceRegistration;
import org.springframework.cloud.netflix.eureka.serviceregistry.EurekaRegistration;
import org.springframework.cloud.netflix.eureka.serviceregistry.EurekaServiceRegistry;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.lang.NonNull;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestTemplate;

import java.net.URI;
import java.net.URL;
import java.net.UnknownHostException;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

/**
 * Eureka server health checker
 * If the Eureka server crashes, and the Eureka server restarts, the Eureka client registry will be cleared to connect to the Eureka server again
 */
@Configuration
@EnableAsync
@EnableScheduling
@ConditionalOnProperty(value = "eureka.client.enabled", havingValue = "true")
@AutoConfigureAfter(EurekaInitializationChecker.class)
public class EurekaServerHealthChecker {

    private final Logger logger = LoggerFactory.getLogger(EurekaInitializationChecker.class);

    /**
     * Connection timeout
     */
    private static final int TIMEOUT = 2000;

    /**
     * Set of individual properties of Eureka servers to know if each server has restarted/renewed and if a registry refresh is needed
     */
    private final Set<EurekaServerProperties> eurekaServerProperties;

    /**
     * Context refresher that will allow to refresh the Eureka client configuration without calling the Actuator API
     */
    private final RefreshScope contextRefresher;

    /**
     * Constructor of the Eureka server health checker.
     * Defines initial properties.
     *
     * @param cr   Context refresher
     * @param esru URL of the Eureka server
     */
    public EurekaServerHealthChecker(@Autowired RefreshScope cr, @Value("${EUREKA_SERVERS_URLS:http://localhost:9999}") String esru) {
        this.contextRefresher = cr;
        this.eurekaServerProperties = new HashSet<>();

        // Collect Eureka servers base URLs
        String[] urls = StringUtils.commaDelimitedListToStringArray(esru);

        try {
            for (String eurekaServerReplicaURL:urls) {
                this.eurekaServerProperties.add(new EurekaServerProperties(new URI(eurekaServerReplicaURL).resolve("/").toURL()));
            }
        } catch (Exception ignored) {
        }

        // Check for Eureka servers restarts
        this.refreshEurekaClientConfiguration();
    }

    public Set<EurekaServerProperties> getEurekaServerProperties() {
        return this.eurekaServerProperties;
    }

    /**
     * Performs health checks concerning the Eureka server by detecting status changes and UUID changes
     */
    @Scheduled(fixedDelay = 30000)
    public void refreshEurekaClientConfiguration() {
        List<CompletableFuture<Boolean>> changes = this.getEurekaServerProperties()
                .stream()
                .map(EurekaServerProperties::detectEurekaServerRestart)
                .toList();

        try {
            boolean changeDetected = (boolean) CompletableFuture.anyOf(changes.toArray(new CompletableFuture[0])).get(500 + (long) this.getEurekaServerProperties().size() * TIMEOUT, TimeUnit.MILLISECONDS);

            if (changeDetected) {
                this.logger.info("Eureka Server change detected ! Refreshing configuration");

                this.contextRefresher.refresh(InstanceInfoFactory.class);
                this.contextRefresher.refresh(DiscoveryClient.class);
                this.contextRefresher.refresh(ConfigClusterResolver.class);
                this.contextRefresher.refresh(EurekaServiceRegistry.class);
                this.contextRefresher.refresh(EurekaRegistration.class);
                this.contextRefresher.refresh(EurekaAutoServiceRegistration.class);
            }
        } catch (Exception ignored) {
        }
    }

    /**
     * Eureka server properties container class.
     * Allows to encapsulate specific properties of each Eureka replica in order to easily detect changes.
     */
    private static class EurekaServerProperties {

        /**
         * Status of the Eureka server
         */
        private ApplicationStatus eurekaServerStatus;

        /**
         * UUID of the Eureka server
         */
        private String eurekaServerUuid;

        /**
         * URL of the Eureka server
         */
        private final URL eurekaServerUrl;

        /**
         * Flag that indicates if the initial start of the Eureka server has been performed
         */
        private boolean hasEurekaServerInitialized;

        /**
         * Constructor of the Eureka server properties.
         *
         * @param url URL of the Eureka server
         */
        public EurekaServerProperties(@NonNull URL url) throws UnknownHostException {
            this.eurekaServerUrl = url;
            this.eurekaServerUuid = "";
            this.eurekaServerStatus = new ApplicationStatus();
            this.hasEurekaServerInitialized = false;
        }

        private ApplicationStatus getEurekaServerStatus() {
            return this.eurekaServerStatus.clone();
        }

        /**
         * Detects Eureka server restart by checking the Eureka server health endpoint and the Eureka server UUID
         *
         * @return Asynchronous result that indicates if the Eureka server restarted
         */
        public CompletableFuture<Boolean> detectEurekaServerRestart() {
            boolean eurekaServerRestarted = false;
            ApplicationStatus previousStatus = this.getEurekaServerStatus();

            try {
                SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
                factory.setConnectTimeout(TIMEOUT/2);
                factory.setReadTimeout(TIMEOUT/2);

                this.eurekaServerStatus = new RestTemplate(factory).getForObject(this.getEurekaServerUrl() + "/actuator/health", ApplicationStatus.class);

                if (this.eurekaServerStatus == null) {
                    this.eurekaServerStatus = new ApplicationStatus();
                    this.eurekaServerStatus.setStatus("DOWN");
                }
            } catch (Exception e) {
                this.eurekaServerStatus = new ApplicationStatus();
                this.eurekaServerStatus.setStatus("DOWN");
            }

            String previousEurekaServerUuid = this.getEurekaServerUuid();
            String actualizedEurekaServerUuid = this.fetchEurekaServerUuid();

            // Eureka server restart detected : client configuration refresh needed
            if (((!this.eurekaServerStatus.equals(previousStatus) && !this.eurekaServerStatus.getStatus().equals(InstanceInfo.InstanceStatus.DOWN)) || !previousEurekaServerUuid.equals(actualizedEurekaServerUuid)) && this.hasEurekaServerInitialized()) {
                eurekaServerRestarted = true;
            }

            // The Eureka server is now started : we can now detect other crashes
            if (!this.hasEurekaServerInitialized() && this.eurekaServerStatus.getStatus().equals(InstanceInfo.InstanceStatus.UP)) {
                this.markEurekaServerAsInitialized();
            }

            return CompletableFuture.completedFuture(eurekaServerRestarted);
        }

        public URL getEurekaServerUrl() {
            return this.eurekaServerUrl;
        }

        public String getEurekaServerUuid() {
            return this.eurekaServerUuid;
        }

        /**
         * Fetch current Eureka server UUID by checking the Eureka server UUID endpoint
         *
         * @return Current Eureka server UUID
         */
        private String fetchEurekaServerUuid() {
            String uuid = null;
            try {
                uuid = new RestTemplate().getForObject(this.getEurekaServerUrl() + "/actuator/uuid", String.class);
            } catch (Exception ignored) {
            }

            if (uuid != null) {
                this.eurekaServerUuid = uuid;
            }

            return uuid;
        }

        public boolean hasEurekaServerInitialized() {
            return this.hasEurekaServerInitialized;
        }

        /**
         * Allows to mark the Eureka Server as initialized
         * This is useful to ignore the first start of the Eureka server as the configuration of the Eureka client is done when the beans are configured
         */
        public void markEurekaServerAsInitialized() {
            this.hasEurekaServerInitialized = true;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (o == null || getClass() != o.getClass()) return false;
            EurekaServerProperties that = (EurekaServerProperties) o;
            return Objects.equals(eurekaServerUrl, that.eurekaServerUrl);
        }

        @Override
        public int hashCode() {
            return Objects.hash(eurekaServerUrl);
        }
    }

}
