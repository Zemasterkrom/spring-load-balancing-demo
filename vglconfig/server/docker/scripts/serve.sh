#!/usr/bin/env sh
mkdir -p /usr/vglconfig/config
touch /usr/vglconfig/config/GIT_CONFIG_BRANCH

if [ -n "${GIT_CONFIG_BRANCH}" ]; then
    echo "${GIT_CONFIG_BRANCH}" > /usr/vglconfig/config/GIT_CONFIG_BRANCH
elif [ -f /usr/vglconfig/config/GIT_CONFIG_BRANCH ] && [ -r /usr/vglconfig/config/GIT_CONFIG_BRANCH ]; then
    GIT_CONFIG_BRANCH="$(cat /usr/vglconfig/config/GIT_CONFIG_BRANCH)"
fi

export GIT_CONFIG_BRANCH="${GIT_CONFIG_BRANCH:-master}"
java -Dspring.config.location=file:/usr/vglconfig/application.properties -XX:TieredStopAtLevel=1 -DGIT_CONFIG_REPOSITORY="${GIT_CONFIG_REPOSITORY}" -DGIT_CONFIG_BRANCH="${GIT_CONFIG_BRANCH}" -jar /usr/vglconfig/app.jar