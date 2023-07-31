#!/usr/bin/env sh

load_and_persist_variables() {
    if [ -n "$1" ]; then
        printf "%s" "$1" > "$2"
    elif test -f "$1" && test -r "$1"; then
        API_HOSTNAME="$(cat "$2")"
    fi
}

configure_environment_variables() {
    if [ -n "${CONTAINER_NAME_ID}" ]; then
        CONTAINER_NAME_ID="$(echo "${CONTAINER_NAME_ID}" | grep "^[[:alpha:]][[:alnum:]_]*$")"
        mkdir -p "/usr/vglservice/config/${CONTAINER_NAME_ID}"
        touch "/usr/vglservice/config/${CONTAINER_NAME_ID}/system_hostname"
        load_and_persist_variables "${API_HOSTNAME}" "/usr/vglservice/config/${CONTAINER_NAME_ID}/system_hostname"
    fi

    export API_HOSTNAME="${API_HOSTNAME:-$(hostname)}"
}

# shellcheck disable=SC2154
main() {
    if [ "${load_core_only}" != "true" ]; then
        configure_environment_variables
        java -Dspring.config.location=file:/usr/vglservice/application.properties -XX:TieredStopAtLevel=1 -DCONFIG_SERVER_URL="${CONFIG_SERVER_URL}" -DENABLE_LOAD_BALANCING="${ENABLE_LOAD_BALANCING:-true}" -DEUREKA_SERVERS_URLS="${EUREKA_SERVERS_URLS}" -DAPI_ALLOWED_ORIGINS="${API_ALLOWED_ORIGINS}" -DAPI_HOSTNAME="${API_HOSTNAME}" -DDB_URL="${DB_URL}" -DDB_USERNAME="${DB_USERNAME}" -DDB_PASSWORD="${DB_PASSWORD}" -jar /usr/vglservice/app.jar
    fi
}

main "$1"