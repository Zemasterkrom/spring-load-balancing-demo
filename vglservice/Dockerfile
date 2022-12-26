FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/vglservice
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 1C -Dmaven.test.skip -DskipTests -Dmaven.javadoc.skip=true clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/vglservice
ENV CONFIG_SERVER_URL=${CONFIG_SERVER_URL}
ENV ENABLE_LOAD_BALANCING=${ENABLE_LOAD_BALANCING}
ENV EUREKA_SERVER_URL=${EUREKA_SERVER_URL}
ENV ALLOWED_ORIGINS=${ALLOWED_ORIGINS}
COPY --from=builder /usr/vglservice/target/*.jar app.jar
COPY ./serve.sh /usr/vglservice
RUN chmod +x ./serve.sh && \
    wget https://github.com/atkrad/wait4x/releases/download/v2.9.1/wait4x-linux-amd64.tar.gz && \
    tar -xvf wait4x-linux-amd64.tar.gz && \
    chmod +x ./wait4x
EXPOSE 8080

ENTRYPOINT ["sh", "-c", "sh /usr/vglservice/serve.sh"]