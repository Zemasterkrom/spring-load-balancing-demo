#!/usr/bin/env sh
mkdir -p /usr/vglloadbalancer/config
touch /usr/vglloadbalancer/config/LOADBALANCER_HOSTNAME

if [ -n "${LOADBALANCER_HOSTNAME}" ]; then
    echo "${LOADBALANCER_HOSTNAME}" > /usr/vglloadbalancer/config/LOADBALANCER_HOSTNAME
elif [ -f /usr/vglloadbalancer/config/LOADBALANCER_HOSTNAME ] && [ -r /usr/vglloadbalancer/config/LOADBALANCER_HOSTNAME ]; then
    LOADBALANCER_HOSTNAME="$(cat /usr/vglloadbalancer/config/LOADBALANCER_HOSTNAME)"
fi

export LOADBALANCER_HOSTNAME="${LOADBALANCER_HOSTNAME:-$(hostname)}"
java -Dspring.config.location=file:/usr/vglloadbalancer/application.properties -XX:TieredStopAtLevel=1 -DCONFIG_SERVER_URL="${CONFIG_SERVER_URL}" -DEUREKA_SERVERS_URLS="${EUREKA_SERVERS_URLS}" -DALLOWED_ORIGINS="${ALLOWED_ORIGINS}" -DLOADBALANCER_HOSTNAME="${LOADBALANCER_HOSTNAME}" -jar /usr/vglloadbalancer/app.jar