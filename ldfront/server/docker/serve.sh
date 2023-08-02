#!/usr/bin/env sh
set -e

# Remove environment variables and remove the temporary JavaScript environment file
cleanup() {
  exit_code="$1"

  if [ -z "${exit_code}" ]; then
    exit_code=0
  fi

  # Remove temporary JavaScript environment file to avoid conflicts with Docker
  if test -f /usr/share/nginx/html/assets/environment.js; then
    echo "Removing temporary JavaScript file /usr/share/nginx/html/assets/environment.js"

    if ! rm /usr/share/nginx/html/assets/environment.js >/dev/null 2>&1; then
      echo "Failed to remove the /usr/share/nginx/html/assets/environment.js temporary JavaScript environment file"
      exit_code=1
    fi
  fi

  exit_script "${exit_code}"
}

exit_script() {
  exit "${1:-0}"
}

# Configures the browser related environment of the application
configure_browser_environment() {
  # API URL
  configure_environment_file /usr/share/nginx/html/assets/environment.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" url "${API_URL:-http://localhost:10000}"
}

# Allows to create environment files, similarly to Java with environment variables.
# In a dockerized or automated environment, this function may be of increased interest if a JavaScript application must
# have access to environment variables when launching the application, which could be loaded from the environment file.
# Example : configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = @JSVALUE@;" valueOne 0 valueTwo 1
#
# Parameters :
#   - $1 : path to the environment file that needs to be created / updated
#   - $2 : environment file encoding
#   - $3 : key placeholder. This placeholder will be used to reference the current key in the environment template.
#   - $4 : value placeholder. This placeholder will be used to reference the current value in the environment template.
#   - $5 : environment template
#   - $6...n : key/value data pairs
configure_environment_file() {
  if [ $# -lt 6 ]; then
    echo "Usage: configure_environment_file <Path to the environment file> <Environment file encoding> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ..." >&2
    return 2
  fi
  
  environment_file_path="$1"
  environment_file_encoding="$2"
  key_placeholder="$3"
  value_placeholder="$4"
  environment_template="$5"

  environment_file_link="${environment_file_path}"
  key_error=false
  content=

  if echo "${environment_file_path}" | grep -q "^\s*$"; then
    echo "The environment file path can't be empty" >&2
    return 2
  fi

  if echo "${key_placeholder}" | grep -q "^\s*$"; then
    echo "The key placeholder can't be empty" >&2
    return 2
  fi

  if echo "${value_placeholder}" | grep -q "^\s*$"; then
    echo "The value placeholder can't be empty" >&2
    return 2
  fi

  if echo "${environment_template}" | grep -q "^\s*$"; then
    echo "The environment template can't be empty" >&2
    return 2
  fi

  if test -d "${environment_file_path}"; then
    echo "File ${environment_file_path} : is a directory" >&2
    return 71
  fi

  if ! test -f "${environment_file_link}"; then
    environment_file_link="${environment_file_link%/*}"

    if [ "${environment_file_link}" = "${environment_file_path}" ]; then
      environment_file_link="."
    fi
  fi

  if ! test -w "${environment_file_link}"; then
    echo "Can't write to ${environment_file_path}" >&2
    return 71
  fi

  shift 5

  for environment_variable_data in "$@"; do
    if test -z "${key}" && ! ${key_error}; then
      if ! echo "${environment_variable_data}" | grep -q "^\s*$"; then
        key="${environment_variable_data}"
      else
        key_error=true
      fi
    else
      value="${environment_variable_data}"

      if ${key_error}; then
        echo "Keys can't be empty. Concerned value : ${value}" >&2
        return 2
      fi

      content="${content}$(echo "${environment_template}" | awk -v key_placeholder="${key_placeholder}" -v value_placeholder="${value_placeholder}" -v key="${key}" -v value="${value}" '{
        while (i=index($0, key_placeholder)) { 
            $0 = substr($0, 1, i-1) key substr($0, i + length(key_placeholder))
        }

        while (i=index($0, value_placeholder)) { 
            $0 = substr($0, 1, i-1) value substr($0, i + length(value_placeholder))
        }

        print
      }')
"

      key=
    fi
  done

  if ! test -z "${key}" && ! ${key_error}; then
    content="${content}$(echo "${environment_template}" | awk -v key_placeholder="${key_placeholder}" -v value_placeholder="${value_placeholder}" -v key="${key}" '{
        while (i=index($0, key_placeholder)) { 
            $0 = substr($0, 1, i-1) key substr($0, i + length(key_placeholder))
        }

        while (i=index($0, value_placeholder)) { 
            $0 = substr($0, 1, i-1) "" substr($0, i + length(value_placeholder))
        }

        print
      }')
"
    key=
  fi

  LC_ALL=${environment_file_encoding:-C.UTF-8} printf "%s" "${content}" > "${environment_file_path}" || return 71
}

# shellcheck disable=SC2154
start() {
  if [ "${load_core_only}" != "true" ]; then
    trap 'cleanup $?' INT TERM EXIT

    # Initialize the browser environment
    configure_browser_environment url "${API_URL:-http://localhost:10000}" /usr/share/nginx/html/assets/environment.js

    # Serve the front
    nginx -g "daemon off;" &

    wait $!
  fi
}

start