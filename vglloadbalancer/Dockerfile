FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/vglloadbalancer
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 4 -DskipTests clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/vglloadbalancer
ENV CONFIG_SERVER_URL=${CONFIG_SERVER_URL}
ENV EUREKA_SERVERS_URLS=${EUREKA_SERVER_URLS}
ENV ALLOWED_ORIGINS=${ALLOWED_ORIGINS}
ENV LOADBALANCER_HOSTNAME=${LOADBALANCER_HOSTNAME:-$(hostname)}
COPY --from=builder /usr/vglloadbalancer/target/*.jar app.jar
EXPOSE 10000

ENTRYPOINT java -Dspring.config.location=file:/usr/vglloadbalancer/application.properties -XX:TieredStopAtLevel=1 -DCONFIG_SERVER_URL=${CONFIG_SERVER_URL} -DEUREKA_SERVERS_URLS=${EUREKA_SERVERS_URLS} -DALLOWED_ORIGINS=${ALLOWED_ORIGINS} -DLOADBALANCER_HOSTNAME=${LOADBALANCER_HOSTNAME:-$(hostname)} -jar /usr/vglloadbalancer/app.jar