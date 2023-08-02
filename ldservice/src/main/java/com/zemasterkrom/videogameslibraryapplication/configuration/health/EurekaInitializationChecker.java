package com.zemasterkrom.videogameslibraryapplication.configuration.health;

import com.netflix.appinfo.InstanceInfo;
import org.springframework.beans.BeansException;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.context.event.ApplicationEnvironmentPreparedEvent;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;
import org.springframework.context.ApplicationListener;
import org.springframework.core.annotation.Order;
import org.springframework.core.env.Environment;
import org.springframework.lang.NonNull;
import org.springframework.retry.support.RetryTemplate;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.CompletableFuture;

/**
 * Allows to check that Eureka replicas are up before starting the Spring Boot application
 */
@Order
public class EurekaInitializationChecker implements ApplicationListener<ApplicationEnvironmentPreparedEvent>, ApplicationContextAware {

    /**
     * Spring application context
     */
    private ApplicationContext applicationContext;

    /**
     * Max number of retries to a Eureka Server
     */
    private int eurekaServerMaxRetries;

    /**
     * Retry delay (ms) between each connection to the Eureka Server
     */
    private int eurekaServerRetryDelay;

    /**
     * Eureka servers replicas URLs
     */
    private String eurekaReplicasUrls;

    /**
     * Flag to handle a SIGTERM / shutdown signal and abort a retry attempt
     */
    private volatile boolean sigterm;

    /**
     * Constructor of the Eureka initialization checker
     */
    public EurekaInitializationChecker() {
        this.applicationContext = null;
        this.eurekaServerMaxRetries = 10;
        this.eurekaServerRetryDelay = 12000;
        this.eurekaReplicasUrls = "http://localhost:9999/eureka";
        this.sigterm = false;

        // Catch SIGTERM signal to close the application when retrying connections to the Eureka server
        Runtime.getRuntime().addShutdownHook(new Thread(() -> this.sigterm = true));
    }

    @Override
    public void setApplicationContext(@NonNull ApplicationContext applicationContext) throws BeansException {
        this.applicationContext = applicationContext;
    }

    /**
     * Logic executed only if the Eureka Client is enabled.
     * Trigger requests across all the replicas and wait until all of them are available.
     *
     * @param event Event triggered when the environment is prepared and ready to be used
     */
    @Override
    public void onApplicationEvent(ApplicationEnvironmentPreparedEvent event) {
        Environment environment = event.getEnvironment();

        if (environment.getProperty("eureka.client.enabled", Boolean.class, true)) {
            String appName = environment.getProperty("spring.application.name", "");
            this.eurekaReplicasUrls = environment.getProperty("eureka.client.service-url.defaultZone", "http://localhost:9999/eureka");
            this.eurekaServerMaxRetries = environment.getProperty("eureka.client.eureka-server-connect-max-retries", Integer.class, 10);
            this.eurekaServerRetryDelay = environment.getProperty("eureka.client.eureka-server-connect-retry-delay", Integer.class, 12000);

            try {
                // Collect Eureka servers base URLs
                String[] urls = StringUtils.commaDelimitedListToStringArray(this.eurekaReplicasUrls);
                URL[] eurekaServerReplicasURL = new URL[urls.length];

                if (eurekaServerReplicasURL.length == 0) {
                    System.err.println(appName + " : No Eureka server specified. Cannot run in load-balancing mode.");
                    this.exit();
                }

                for (int i = 0; i < eurekaServerReplicasURL.length; i++) {
                    eurekaServerReplicasURL[i] = new URI(urls[i]).resolve("/").toURL();
                }

                System.out.println(appName + " : Trying to establish a connection to the Eureka replicas ...");

                // Execute parallel requests on Eureka servers until all servers are available
                List<ApplicationStatus> status = Arrays.stream(eurekaServerReplicasURL)
                        .map(url -> {
                            try {
                                return this.waitForEurekaServerAvailability(url).exceptionally(e -> {
                                    System.err.println(e.getMessage());
                                    this.exit();

                                    return null;
                                });
                            } catch (IOException e) {
                                System.err.println(e.getMessage());
                                this.exit();
                            }

                            return null;
                        }).filter(Objects::nonNull)
                        .filter(future -> future.join().getStatus().equals(InstanceInfo.InstanceStatus.UP))
                        .toList()
                        .stream()
                        .map(CompletableFuture::join)
                        .toList();

                if (status.size() == 0) {
                    System.err.println(appName + " : No Eureka server available. Cannot run in load-balancing mode.");
                    this.exit();
                }
            } catch (MalformedURLException | URISyntaxException e) {
                System.err.println(appName + " : eureka.client.service-url.defaultZone is malformed. Aborting.");
                this.exit();
            }
        }
    }

    /**
     * Performs checks against a Eureka replica URL until a timeout is reached
     *
     * @param url URL of the Eureka replica
     * @return Asynchronous result of the Eureka replica retries (success or fail)
     * @throws IOException Exception if termination signal is received during Retry checks, which means that the application should close
     */
    private CompletableFuture<ApplicationStatus> waitForEurekaServerAvailability(URL url) throws IOException {
        ApplicationStatus failedEurekaServerStatus = new ApplicationStatus();
        failedEurekaServerStatus.setStatus(InstanceInfo.InstanceStatus.DOWN);

        try {
            ApplicationStatus successfulEurekaServerRetry = RetryTemplate.builder().maxAttempts(this.eurekaServerMaxRetries >= 0 ? this.eurekaServerMaxRetries + 1 : 1).fixedBackoff(this.eurekaServerRetryDelay).retryOn(IllegalStateException.class).build().execute(ctx -> {
                if (this.sigterm) {
                    throw new IOException("Received SIGTERM signal. Aborting");
                }

                try {
                    ApplicationStatus as = new RestTemplate().getForObject(url + "/actuator/health", ApplicationStatus.class);

                    if (as != null && as.getStatus().equals(InstanceInfo.InstanceStatus.UP)) {
                        return as;
                    } else {
                        throw new IllegalStateException("Eureka server is currently unreachable. Retrying ...");
                    }
                } catch (RestClientException e) {
                    throw new IllegalStateException("Eureka server is currently unreachable. Retrying ...");
                }
            });

            return CompletableFuture.completedFuture(successfulEurekaServerRetry);
        } catch (IllegalStateException failedRetry) {
            throw new IOException("Cannot establish connection to " + url.toString() + ". Aborting.");
        }
    }

    private void exit() {
        if (this.applicationContext != null) {
            System.exit(SpringApplication.exit(this.applicationContext, () -> 126));
        } else {
            System.exit(126);
        }
    }
}
