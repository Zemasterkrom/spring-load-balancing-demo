#!/usr/bin/env sh

load_and_persist_variables() {
    if [ -n "$1" ]; then
        printf "%s" "$1" > "$2"
    elif test -f "$1" && test -r "$1"; then
        LOADBALANCER_HOSTNAME="$(cat "$2")"
    fi
}

configure_environment_variables() {
    mkdir -p /usr/vglloadbalancer/config
    touch /usr/vglloadbalancer/config/LOADBALANCER_HOSTNAME
    load_and_persist_variables "${LOADBALANCER_HOSTNAME}" "/usr/vglloadbalancer/config/LOADBALANCER_HOSTNAME"

    export LOADBALANCER_HOSTNAME="${LOADBALANCER_HOSTNAME:-$(hostname)}"
}

# shellcheck disable=SC2154
main() {
    if [ "${load_core_only}" != "true" ]; then
        configure_environment_variables
        java -Dspring.config.location=file:/usr/vglloadbalancer/application.properties -XX:TieredStopAtLevel=1 -DCONFIG_SERVER_URL="${CONFIG_SERVER_URL}" -DEUREKA_SERVERS_URLS="${EUREKA_SERVERS_URLS}" -DALLOWED_ORIGINS="${ALLOWED_ORIGINS}" -DLOADBALANCER_HOSTNAME="${LOADBALANCER_HOSTNAME}" -jar /usr/vglloadbalancer/app.jar
    fi
}

main