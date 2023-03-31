package com.zemasterkrom.vglloadbalancer;

import com.zemasterkrom.vglloadbalancer.configuration.health.EurekaInitializationChecker;
import com.zemasterkrom.vglloadbalancer.configuration.health.WinTerminationSignalHandler;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.retry.annotation.EnableRetry;

@EnableRetry
@SpringBootApplication
public class VGLLoadBalancerApplication {
    public static void main(String[] args) {
        SpringApplicationBuilder springApplicationBuilder = new SpringApplicationBuilder(VGLLoadBalancerApplication.class);
        springApplicationBuilder.listeners(new WinTerminationSignalHandler());
        springApplicationBuilder.listeners(new EurekaInitializationChecker());
        springApplicationBuilder.run(args);
    }
}

