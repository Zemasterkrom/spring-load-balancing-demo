package com.zemasterkrom.videogameslibraryapplication;

import com.zemasterkrom.videogameslibraryapplication.configuration.health.EurekaInitializationChecker;
import com.zemasterkrom.videogameslibraryapplication.configuration.health.WinTerminationSignalHandler;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.retry.annotation.EnableRetry;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

import java.util.Locale;

@SpringBootApplication
@EnableRetry
public class VideoGameLibraryService {

	public static void main(String[] args) {
		SpringApplicationBuilder springApplicationBuilder = new SpringApplicationBuilder(VideoGameLibraryService.class);
		springApplicationBuilder.listeners(new WinTerminationSignalHandler());
		springApplicationBuilder.listeners(new EurekaInitializationChecker());
		springApplicationBuilder.run(args);
	}

}
