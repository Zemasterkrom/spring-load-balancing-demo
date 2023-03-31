#!/usr/bin/env sh
set -e

# Remove environment variables and remove the temporary JavaScript environment file
cleanup() {
  set +e
  exit_code="$1"

  if [ -z "${exit_code}" ]; then
    exit_code=0
  fi

  if ! ${cleanup_completed}; then
    # Remove temporary JavaScript environment file to avoid conflicts with Docker
    if [ -f /usr/share/nginx/html/assets/environment.js ]; then
      echo "Removing temporary JavaScript file /usr/share/nginx/html/assets/environment.js"

      if ! rm /usr/share/nginx/html/assets/environment.js >/dev/null 2>&1; then
        echo "Failed to remove the /usr/share/nginx/html/assets/environment.js temporary JavaScript environment file"
        exit_code=1
      fi
    fi

    cleanup_completed=true
  fi

  set -e
  exit "${exit_code}"
}

trap 'cleanup $?' INT TERM EXIT

# Graceful cleanup flag
cleanup_completed=false

# Initialize the browser environment
sh /usr/vglfront/configure.sh "$(sh /usr/vglfront/getenv.sh API_URL http://localhost:10000)" /usr/share/nginx/html/assets/environment.js

# Serve the front
nginx -g "daemon off;" &

wait $!