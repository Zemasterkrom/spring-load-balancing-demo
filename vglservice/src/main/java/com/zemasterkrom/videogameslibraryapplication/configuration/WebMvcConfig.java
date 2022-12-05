package com.zemasterkrom.videogameslibraryapplication.configuration;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    @Value("${spring.api.cors.allowed-origins}")
    private String allowedOrigins;

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        CorsRegistration registration = registry.addMapping("/**");
        String[] allowedOriginsList = allowedOrigins.split(",");

        for (String allowedOrigin:allowedOriginsList) {
            registration.allowedOrigins(allowedOrigin);
        }

        registration.allowedMethods("GET", "POST", "PUT", "DELETE").allowCredentials(true);
    }
}