FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/vglconfig
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 4 -DskipTests clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/vglconfig
ENV GIT_CONFIG_REPOSITORY=${GIT_CONFIG_REPOSITORY}
ENV GIT_CONFIG_BRANCH=${GIT_CONFIG_BRANCH}
COPY --from=builder /usr/vglconfig/target/*.jar app.jar
EXPOSE 8888

ENTRYPOINT java -Dspring.config.location=file:/usr/vglconfig/application.properties -XX:TieredStopAtLevel=1 -DGIT_CONFIG_REPOSITORY=${GIT_CONFIG_REPOSITORY} -DGIT_CONFIG_BRANCH=${GIT_CONFIG_BRANCH} -jar /usr/vglconfig/app.jar