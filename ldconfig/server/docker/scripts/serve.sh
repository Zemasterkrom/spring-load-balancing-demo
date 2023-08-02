#!/usr/bin/env sh

load_and_persist_variables() {
    if [ -n "$1" ]; then
        printf "%s" "$1" > "$2"
    elif test -f "$1" && test -r "$1"; then
        GIT_CONFIG_BRANCH="$(cat "$2")"
    fi
}

configure_environment_variables() {
    mkdir -p /usr/ldconfig/config
    touch /usr/ldconfig/config/GIT_CONFIG_BRANCH
    load_and_persist_variables "${GIT_CONFIG_BRANCH}" "/usr/ldconfig/config/GIT_CONFIG_BRANCH"

    export GIT_CONFIG_BRANCH="${GIT_CONFIG_BRANCH:-master}"
}

# shellcheck disable=SC2154
main() {
    if [ "${load_core_only}" != "true" ]; then
        configure_environment_variables
        java -Dspring.config.location=file:/usr/ldconfig/application.properties -XX:TieredStopAtLevel=1 -DGIT_CONFIG_REPOSITORY="${GIT_CONFIG_REPOSITORY}" -DGIT_CONFIG_BRANCH="${GIT_CONFIG_BRANCH}" -jar /usr/ldconfig/app.jar
    fi
}

main