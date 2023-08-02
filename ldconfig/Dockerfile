FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/ldconfig
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 4 -DskipTests clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/ldconfig
COPY --from=builder /usr/ldconfig/target/*.jar app.jar
COPY ./server/docker/scripts/*.sh ./
EXPOSE 8888

ENTRYPOINT java -Dspring.config.location=file:/usr/ldconfig/resources/application.properties -XX:TieredStopAtLevel=1 -jar /usr/ldconfig/app.jar