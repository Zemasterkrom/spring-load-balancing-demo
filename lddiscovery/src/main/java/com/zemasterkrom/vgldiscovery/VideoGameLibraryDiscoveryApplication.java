package com.zemasterkrom.lddiscovery;

import com.zemasterkrom.lddiscovery.configuration.health.WinTerminationSignalHandler;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@EnableEurekaServer
@EnableDiscoveryClient
@SpringBootApplication
public class VideoGameLibraryDiscoveryApplication {

    public static void main(String[] args) {
        SpringApplicationBuilder springApplicationBuilder = new SpringApplicationBuilder(VideoGameLibraryDiscoveryApplication.class);
        springApplicationBuilder.listeners(new WinTerminationSignalHandler());
        springApplicationBuilder.run(args);
    }

}
