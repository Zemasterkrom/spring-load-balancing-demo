#!/bin/sh
set -e

if ! [ -z "${EUREKA_SERVER_URL}" ]; then
  ENABLE_LOAD_BALANCING="true"
else
  ENABLE_LOAD_BALANCING="false"
fi

java -Dspring.config.location=file:/usr/vglservice/application.properties -DCONFIG_SERVER_URL=${CONFIG_SERVER_URL} -DENABLE_LOAD_BALANCING=${ENABLE_LOAD_BALANCING} -DEUREKA_SERVER_URL=${EUREKA_SERVER_URL} -DALLOWED_ORIGINS=${ALLOWED_ORIGINS} -XX:TieredStopAtLevel=1 -jar /usr/vglservice/app.jar