#!/bin/sh
set -e

if ! [ -z "${EUREKA_SERVER_URL}" ]; then
  ENABLE_LOAD_BALANCING="true"
else
  ENABLE_LOAD_BALANCING="false"
fi

java -jar -Dspring.config.location=file:/usr/vglservice/application.properties /usr/vglservice/app.jar -DCONFIG_SERVER_URL=${CONFIG_SERVER_URL} -DENABLE_LOAD_BALANCING=${ENABLE_LOAD_BALANCING} -DEUREKA_SERVER_URL=${EUREKA_SERVER_URL} -DALLOWED_ORIGINS=${ALLOWED_ORIGINS}