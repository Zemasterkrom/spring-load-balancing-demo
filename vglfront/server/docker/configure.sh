#!/usr/bin/env sh

url_key_check=$(grep "window['environment']['url'].*=.*" "$2" 2>/dev/null)

if [ ! -f "$2" ] || [ -z "${url_key_check}" ]; then
  echo "window['environment']['url'] = \"$1\";" > "$2"
else
  sed -i "/window['environment']['url'].*=.*/d" "$2"
  echo "window['environment']['url'] = \"$1\";" > "$2"
fi