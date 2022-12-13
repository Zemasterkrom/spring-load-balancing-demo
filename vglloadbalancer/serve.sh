#!/bin/sh
set -e

java -jar /usr/vglloadbalancer/app.jar -DCONFIG_SERVER_URL=${CONFIG_SERVER_URL} -DEUREKA_SERVER_URL=${EUREKA_SERVER_URL} -DALLOWED_ORIGINS=${ALLOWED_ORIGINS}