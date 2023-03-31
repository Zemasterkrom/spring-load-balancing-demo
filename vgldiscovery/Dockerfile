FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/vgldiscovery
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 4 -DskipTests clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/vgldiscovery
ENV CONFIG_SERVER_URL=${CONFIG_SERVER_URL}
COPY --from=builder /usr/vgldiscovery/target/*.jar app.jar
EXPOSE 9999

ENTRYPOINT java -Dspring.config.location=file:/usr/vgldiscovery/application.properties -XX:TieredStopAtLevel=1 -DCONFIG_SERVER_URL=${CONFIG_SERVER_URL} -jar /usr/vgldiscovery/app.jar