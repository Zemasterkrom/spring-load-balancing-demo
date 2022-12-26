FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/vglloadbalancer
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 1C -Dmaven.test.skip -DskipTests -Dmaven.javadoc.skip=true clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/vglloadbalancer
ENV CONFIG_SERVER_URL=${CONFIG_SERVER_URL}
ENV EUREKA_SERVER_URL=${EUREKA_SERVER_URL}
ENV ALLOWED_ORIGINS=${ALLOWED_ORIGINS}
COPY --from=builder /usr/vglloadbalancer/target/*.jar app.jar
RUN wget https://github.com/atkrad/wait4x/releases/download/v2.9.1/wait4x-linux-amd64.tar.gz && \
    tar -xvf wait4x-linux-amd64.tar.gz && \
    chmod +x ./wait4x
EXPOSE 10000

ENTRYPOINT java -Dspring.config.location=file:/usr/vglloadbalancer/application.properties -DCONFIG_SERVER_URL=${CONFIG_SERVER_URL} -DEUREKA_SERVER_URL=${EUREKA_SERVER_URL} -DALLOWED_ORIGINS=${ALLOWED_ORIGINS} -XX:TieredStopAtLevel=1 -jar /usr/vglloadbalancer/app.jar