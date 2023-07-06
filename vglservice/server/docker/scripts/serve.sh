#!/usr/bin/env sh
if [ -n "${CONTAINER_NAME_ID}" ]; then
    CONTAINER_NAME_ID="$(echo "${CONTAINER_NAME_ID}" | grep "^[[:alpha:]][[:alnum:]_]*$")"
    mkdir -p "/usr/vglservice/config/${CONTAINER_NAME_ID}"
    touch "/usr/vglservice/config/${CONTAINER_NAME_ID}/system_hostname"

    if [ -n "${API_HOSTNAME}" ]; then
        echo "${API_HOSTNAME}" > "/usr/vglservice/config/${CONTAINER_NAME_ID}/system_hostname"
    elif [ -f "/usr/vglservice/config/${CONTAINER_NAME_ID}/system_hostname" ] && [ -r "/usr/vglservice/config/${CONTAINER_NAME_ID}/system_hostname" ]; then
        API_HOSTNAME="$(cat "/usr/vglservice/config/${CONTAINER_NAME_ID}/system_hostname")"
    fi
fi

export API_HOSTNAME="${API_HOSTNAME:-$(hostname)}"
java -Dspring.config.location=file:/usr/vglservice/application.properties -XX:TieredStopAtLevel=1 -DCONFIG_SERVER_URL="${CONFIG_SERVER_URL}" -DENABLE_LOAD_BALANCING="${ENABLE_LOAD_BALANCING:-true}" -DEUREKA_SERVERS_URLS="${EUREKA_SERVERS_URLS}" -DAPI_ALLOWED_ORIGINS="${API_ALLOWED_ORIGINS}" -DAPI_HOSTNAME="${API_HOSTNAME}" -DDB_URL="${DB_URL}" -DDB_USERNAME="${DB_USERNAME}" -DDB_PASSWORD="${DB_PASSWORD}" -jar /usr/vglservice/app.jar