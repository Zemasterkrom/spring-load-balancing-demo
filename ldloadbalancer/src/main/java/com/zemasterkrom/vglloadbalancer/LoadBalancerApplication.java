package com.zemasterkrom.ldloadbalancer;

import com.zemasterkrom.ldloadbalancer.configuration.health.EurekaInitializationChecker;
import com.zemasterkrom.ldloadbalancer.configuration.health.WinTerminationSignalHandler;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.retry.annotation.EnableRetry;

@EnableRetry
@SpringBootApplication
public class LoadBalancerApplication {
    public static void main(String[] args) {
        SpringApplicationBuilder springApplicationBuilder = new SpringApplicationBuilder(LoadBalancerApplication.class);
        springApplicationBuilder.listeners(new WinTerminationSignalHandler());
        springApplicationBuilder.listeners(new EurekaInitializationChecker());
        springApplicationBuilder.run(args);
    }
}

