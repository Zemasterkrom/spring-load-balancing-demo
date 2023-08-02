FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/ldservice
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 4 -DskipTests clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/ldservice
ENV CONFIG_SERVER_URL=${CONFIG_SERVER_URL}
ENV ENABLE_LOAD_BALANCING=${ENABLE_LOAD_BALANCING}
ENV EUREKA_SERVERS_URLS=${EUREKA_SERVER_URLS}
ENV API_ALLOWED_ORIGINS=${API_ALLOWED_ORIGINS}
ENV API_HOSTNAME=${API_HOSTNAME:-}
ENV DB_URL=${DB_URL}
ENV DB_USERNAME=${DB_USERNAME}
ENV DB_PASSWORD=${DB_PASSWORD}
ENV CONTAINER_ID=${CONTAINER_ID}
COPY --from=builder /usr/ldservice/target/*.jar app.jar
COPY ./server/docker/scripts/*.sh ./
EXPOSE 8080

ENTRYPOINT ["/usr/ldservice/serve.sh"]