FROM maven:3.8-eclipse-temurin-17 as builder

WORKDIR /usr/ldconfig
COPY src src/
COPY pom.xml .
RUN mvn -f pom.xml -T 4 -DskipTests clean package

FROM eclipse-temurin:17-jre

WORKDIR /usr/ldconfig
ENV GIT_CONFIG_REPOSITORY=${GIT_CONFIG_REPOSITORY}
ENV GIT_CONFIG_BRANCH=${GIT_CONFIG_BRANCH}
COPY --from=builder /usr/ldconfig/target/*.jar app.jar
COPY ./server/docker/scripts/*.sh ./
EXPOSE 8888

ENTRYPOINT ["/usr/ldconfig/serve.sh"]