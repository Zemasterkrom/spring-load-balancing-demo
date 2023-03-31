#!/usr/bin/env sh
value=$(env | grep "^$1=.*$" | awk 'BEGIN {ORS=""}; {n=split($0,value,"=")} END{for (i = 2; i <= n; i++) {if (i >= 3) print "="; print value[i]}}')

if [ -z "${value}" ]; then
  echo "$2"
fi

echo "${value}"