package com.zemasterkrom.vglconfig;

import com.zemasterkrom.vglconfig.configuration.health.WinTerminationSignalHandler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.cloud.config.server.EnableConfigServer;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

import javax.swing.*;
import java.io.File;
import java.util.Collections;
import java.util.Set;

/**
 * Serveur de configuration de l'API
 */
@EnableConfigServer
@EnableScheduling
@SpringBootApplication
public class VideoGameLibraryConfigApplication {

    public static void main(String[] args) {
        SpringApplicationBuilder springApplicationBuilder = new SpringApplicationBuilder(VideoGameLibraryConfigApplication.class);
        springApplicationBuilder.listeners(new WinTerminationSignalHandler());
        springApplicationBuilder.run(args);
    }

}
