FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/vgldiscovery
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 1C -Dmaven.test.skip -DskipTests -Dmaven.javadoc.skip=true clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/vgldiscovery
ENV CONFIG_SERVER_URL=${CONFIG_SERVER_URL}
COPY --from=builder /usr/vgldiscovery/target/*.jar app.jar
RUN wget https://github.com/atkrad/wait4x/releases/download/v2.9.1/wait4x-linux-amd64.tar.gz && \
    tar -xvf wait4x-linux-amd64.tar.gz && \
    chmod +x ./wait4x
EXPOSE 9999

ENTRYPOINT java -Dspring.config.location=file:/usr/vgldiscovery/application.properties -DCONFIG_SERVER_URL=${CONFIG_SERVER_URL} -XX:TieredStopAtLevel=1 -jar /usr/vgldiscovery/app.jar