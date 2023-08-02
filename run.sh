#!/usr/bin/env sh

test_shell_path_detection_ability() {
  [ "${0%$1}" != "$0" ]
}

# Change to the script directory if not in the same directory as the script
cd_to_script_dir() {
  if [ -z "${changed_to_base_dir}" ]; then
    changed_to_base_dir=false
  fi

  if ! ${changed_to_base_dir}; then
    if [ -n "${context_dir}" ]; then
      cd_dir="${context_dir}"
    elif test_shell_path_detection_ability "$1"; then
      cd_dir="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
    fi

    if [ -n "${cd_dir}" ]; then
      if ! test -d "${cd_dir}"; then
        echo "${cd_dir} is not a directory. Unable to continue." >&2
        return 126
      fi

      if ! cd "${cd_dir}" >/dev/null 2>&1; then
        echo "Unable to switch to the ${cd_dir} base directory of the script. Unable to continue." >&2
        return 126
      fi
    fi

    if ! test -f "$1"; then
      echo "Unable to find the base script in the changed ${cd_dir} directory. Unable to continue." >&2
      return 127
    fi

    script_directory="$(pwd)"
  fi

  if [ -n "${script_directory}" ] && [ "$(pwd)" != "${script_directory}" ]; then
    if ! cd "${script_directory}" >/dev/null 2>&1; then
      echo "Unable to switch to the ${script_directory} base directory of the script. Unable to continue." >&2
      return 126
    fi
  fi

  if [ -z "${changed_to_base_dir}" ] || [ "${changed_to_base_dir}" = "false" ]; then
    changed_to_base_dir=true
  fi
}

# Generates a random number within a range.
#
# Parameters :
#    - $1 / $2: random range. The order does not matter.
#
# Outputs:
#    A random number within the specified range. If no range is specified, the generated number will be between 0 and 1.
#    If only one argument is specified, the minimum will be 0 and the maximum will be the specified argument.
#    If only one argument is specified and the number is negative, the maximum will be 0.
random_number() {
  min=0
  max=1

  # Random number between 0 and $1
  if [ -n "$1" ] && [ -z "$2" ]; then
    max=$1
  fi

  # Random number between $1 and $2
  if [ -n "$1" ] && [ -n "$2" ]; then
    min=$1
    max=$2

    if ! expr "${min}" : '^-\?[0-9]\+$' >/dev/null 2>&1; then
      return 2
    fi
  fi

  if ! expr "${max}" : '^-\?[0-9]\+$' >/dev/null 2>&1; then
    return 2
  fi

  # Swap the minimum and maximum if the order of the arguments is reversed
  if [ "${min}" -gt "${max}" ]; then
    new_min=${max}
    max=${min}
    min=${new_min}
  fi

  # Generate a random seed
  # The seed calculation is not POSIX-compliant.
  # However, checks are performed on the result with the POSIX expr command to verify that the generated seed is a number.
  # If it is not a number, a fallback is provided: wait a second for awk to generate a different seed from the previous one in a POSIX-compliant way. This ends up being POSIX-compliant.
  # shellcheck disable=SC2039
  seed=$(od -An -N4 -tu4 </dev/urandom 2>/dev/null || date +%s%3N 2>/dev/null || echo ${RANDOM})
  seed="${seed# *}"

  if ! expr "${seed}" : '^[0-9]\+$' >/dev/null 2>&1; then
    seed=""
  fi

  if [ -z "${seed}" ]; then
    sleep 1
  fi

  awk "
BEGIN {
  srand(${seed})
  num = ${min} + rand() * (${max} - ${min})
  if (num < 0 && num > -0.5) num = 0
  printf(\"%.0f\", num)
}"
}

# Reads an environment file and sets the values in the current environment.
# Escape characters in environment files using the \ character.
# The keys associated with the parsed environment variables are exported in a variable ENVIRONMENT_FILE_KEYS.
# Do not call the function using a command substitution because the exported variables will not be visible.
# You can access the keys using $ENVIRONMENT_FILE_KEYS after calling read_environment_file.
#
# Parameters :
#   - $1 : Path of the environment file
#   - $2 : File encoding. Default is UTF8.
#
# Outputs :
#   Space separated list containing the keys of the loaded environment file.
read_environment_file() {
  if [ -n "$1" ]; then
    ENVIRONMENT_FILE_KEYS=""
    ENVIRONMENT_FILE_VARIABLES_DATA="$(
      LC_CTYPE=${2:-C.UTF-8} LC_COLLATE=${2:-C.UTF-8} LC_MONETARY=${2:-C.UTF-8} LC_NUMERIC=${2:-C.UTF-8} LC_TIME=${2:-C.UTF-8} awk '
/^[a-zA-Z][a-zA-Z0-9_]*=([^ \t\r\n\v\f].*|[^ \t\r\n\v\f]*)$/ {
    consecutive_backslashes_count = 0
    new_value_length = 0
    found_quote = ""
    splitted_data_length = split($0, key_value, "=")

    key = key_value[1]
    value = ""
    new_value = ""

    # Retrieve the complete value
    for (i = 2; i <= splitted_data_length; i++) {
      value = value""key_value[i]

      if (i != splitted_data_length) {
        value = value"="
      }
    }

    value_length = split(value, value_chars, "")

    # Process and decode the value
    for (i = 1; i <= value_length; i++) {
      # Process backslashes escaping
      if (value_chars[i] == "\\" && value_chars[i+1] != "\\") {
        consecutive_backslashes_count++
        continue
      }

      if (value_chars[i] == "\\" && value_chars[i+1] == "\\") {
        consecutive_backslashes_count+=2
        i++
      }

      # Count the blank characters that need to be removed
      if (value_chars[i-1] != "\\" && match(value_chars[i], /[ \t]/)) {
        trailing_whitespace_count++
      } else {
        trailing_whitespace_count = 0
      }

      # The number of backslashes is even : we must check the possible presence of slashes
      if (consecutive_backslashes_count%2 == 0) {
        consecutive_backslashes_count = 0
        skip = 0
        value_to_concatenate = ""

        # Opening quote found
        if (match(value_chars[i], /['\''"]/)) {
          found_quote = value_chars[i]

          # Process and search for the closing quote
          for (j = i+1; j <= value_length; j++) {
            # Process backslashes escaping
            if (value_chars[j] == "\\" && value_chars[j+1] != "\\") {
              consecutive_backslashes_count++

              # Failed to detect the closing quote, ending and printing the opening quote
              if (j == value_length) {
                value_to_concatenate = found_quote""value_to_concatenate
                new_value_length++
                i = j
              }

              continue
            }

            if (value_chars[j] == "\\" && value_chars[j+1] == "\\") {
              consecutive_backslashes_count+=2
              j++
            }

            # Count the additional blank characters that need to be removed
            if (value_chars[j-1] != "\\" && match(value_chars[j], /[ \t]/)) {
              trailing_whitespace_count++
            } else {
              trailing_whitespace_count = 0
            }

            # Closing quote detected, quotes are ignored
            if (consecutive_backslashes_count % 2 == 0 && found_quote != "" && value_chars[j] == found_quote) {
              found_quote = ""
              consecutive_backslashes_count = 0
              skip = 1
              i = j
              break
            }

            if (value_chars[j] != "\\") {
              consecutive_backslashes_count = 0
            }

            value_to_concatenate = value_to_concatenate""value_chars[j]
            new_value_length++

            # Failed to detect the closing quote, ending and printing the opening quote
            if (j == value_length) {
              value_to_concatenate = found_quote""value_to_concatenate
              new_value_length++
              i = j
            }
          }
        }

        # No pairs of quotes detected : append the current character
        if (skip == 0 && value_to_concatenate == "") {
          value_to_concatenate = value_chars[i]
          new_value_length++
        }

        new_value = new_value""value_to_concatenate
      } else {
        new_value = new_value""value_chars[i]
        new_value_length++
      }

      if (value_chars[i] != "\\") {
        consecutive_backslashes_count = 0
      }
    }

    # Retrieve only relevant characters (remove trailing whitespace)
    new_value = substr(new_value, 1, new_value_length - trailing_whitespace_count)

    print key"="new_value
  }
' "$1"
    )" || return $?

    while IFS='=' read -r KEY VALUE; do
      if [ -n "${KEY}" ]; then
        export "${KEY}"="${VALUE}"
        ENVIRONMENT_FILE_KEYS="${ENVIRONMENT_FILE_KEYS}${KEY} "
      fi
    done <<EOF
$(printf "%s" "${ENVIRONMENT_FILE_VARIABLES_DATA}")
EOF
    export ENVIRONMENT_FILE_KEYS="${ENVIRONMENT_FILE_KEYS% *}"
  else
    printf "%s\n" "Usage : read_environment_file <Path of the environment file> [File encoding]" >&2
    return 2
  fi
}

########################################
# Process management related functions #
########################################

# Returns information about the process according to the chosen process check strategy
#
# Parameters :
#   - $1 : process ID
#
# Outputs:
#   Information about the process according to the chosen process check strategy
get_process_info() {
  if [ -z "$1" ] || ! expr "$1" : "^[0-9]\+$" >/dev/null 2>&1; then
    return 2
  fi

  # Return process information according to the existence control strategy
  check_return_process_info "$(ps -p "$1" 2>/dev/null | sed -n 2p)"
}

check_return_process_info() {
  if [ -z "$1" ]; then
    return 3
  fi

  echo "$1"
}

# Check the consistency of the processes to avoid killing the wrong processes
#
# Parameters :
#   - $1 : custom check command (optional). If it is empty, the default check using the PID and the process start time will be used.
#   - $2 : registered process PID
check_process_existence() {
  # Prioritized check : check using the custom command
  if [ -n "$1" ]; then
    if eval "$1"; then
      return
    fi
  fi

  if [ -z "$2" ]; then
    return 2
  fi

  # Check if process is still alive
  if [ "$2" = "$$" ]; then
    return
  fi

  for job_PID in $(jobs -p); do
    if [ "${job_PID}" = "$2" ] && [ -n "$(get_process_info "$2")" ]; then
      return
    fi
  done

  return 3
}

# Wait for a process to start
#
# Parameters :
#   - $1 : service name
#   - $2 : process ID
#   - $3 : timeout in seconds
wait_for_process_to_start() {
  if [ -z "$1" ] || ! expr "$1" : "^[a-zA-Z][a-zA-Z0-9_]*$" >/dev/null 2>&1 || [ -z "$2" ] || ! expr "$2" : "^[0-9]\+$" >/dev/null 2>&1 || [ -z "$3" ] || ! expr "$3" : "^[0-9]\+$" >/dev/null 2>&1; then
    return 2
  fi

  # Run the checks
  echo "Waiting for $1 with PID $2 to start ... Please wait ..."
  safe_wait_for_process_to_start "$1" "$2" "$3" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"
}

# Avoid concurrency and interruption problems by using a "safe wait" method
#
# Parameters :
#   - $1...$3 : same parameters
#   - $4 : starting Unix timestamp
#   - $5 : current Unix timestamp after sleep
safe_wait_for_process_to_start() {
  if [ -z "${4%% }" ]; then # The output of the start timestamp is empty, mainly because the execution of the command has been interrupted: a re-execution of the function is necessary
    safe_wait_for_process_to_start "$1" "$2" "$3" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"
  fi

  if [ -z "${5%% }" ]; then # The output of the current timestamp is empty, mainly because the execution of the command has been interrupted: a re-execution of the function is necessary
    safe_wait_for_process_to_start "$1" "$2" "$3" "$4" "$(date +%s 2>/dev/null)"
  fi

  if [ -z "$(get_process_info "$2")" ]; then
    if [ "$(($5 - $4))" -ge "$3" ]; then
      echo "$1 with PID $2 has not started. Cannot continue." >&2
      return 3
    fi
  else
    return 0
  fi

  # Sleep and update timestamp data
  sleep 1
  safe_wait_for_process_to_start "$1" "$2" "$3" "$4" "$(date +%s 2>/dev/null)"
}

# Wait for a process to stop
#
# Parameters :
#   - $1 : service name
#   - $2 : process ID
#   - $3 : timeout in seconds
wait_for_process_to_stop() {
  if [ -z "$1" ] || ! expr "$1" : "^[a-zA-Z][a-zA-Z0-9_]*$" >/dev/null 2>&1 || [ -z "$2" ] || ! expr "$2" : "^[0-9]\+$" >/dev/null 2>&1 || [ -z "$3" ] || ! expr "$3" : "^[0-9]\+$" >/dev/null 2>&1; then
    return 2
  fi

  # Run the checks
  echo "Waiting for $1 with PID $2 to stop ($3 seconds) ..."
  safe_wait_for_process_to_stop "$1" "$2" "$3" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"
}

# Avoid concurrency and interruption problems by using a "safe wait" method
#
# Parameters :
#   - $1...$3 : same parameters
#   - $4 : starting Unix timestamp
#   - $5 : current Unix timestamp after sleep
safe_wait_for_process_to_stop() {
  if [ -z "${4%% }" ]; then # The output of the start timestamp is empty, mainly because the execution of the command has been interrupted: a re-execution of the function is necessary
    safe_wait_for_process_to_stop "$1" "$2" "$3" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"
  fi

  if [ -z "${5%% }" ]; then # The output of the current timestamp is empty, mainly because the execution of the command has been interrupted: a re-execution of the function is necessary
    safe_wait_for_process_to_stop "$1" "$2" "$3" "$4" "$(date +%s 2>/dev/null)"
  fi

  # Check the process existence
  if check_process_existence "" "$2" 2>/dev/null; then
    if [ "$(($5 - $4))" -ge "$3" ]; then
      echo "Wait timeout exceeded for $1 with PID $2" >&2
      return 3
    fi
  else
    return 0
  fi

  # Sleep and update timestamp data
  sleep 1
  safe_wait_for_process_to_stop "$1" "$2" "$3" "$4" "$(date +%s 2>/dev/null)"
}

# Register a process in the processes list
#
# Parameters :
#   - $1 : name of the service
#   - $2 : process ID (optional : stop or kill command required)
#   - $3 : stop command (optional)
#   - $4 : kill command (optional)
#   - $5 : check command (optional)
#   - $6 : indicates if the process spawn other processes (true or false)
#   - $7 : temporary runner file
register_process_info() {
  # Process ID can be empty: in this case, a stop or kill command is required
  if echo "$2" | grep "^\s*$" >/dev/null && echo "$3" | grep "^\s*$" >/dev/null && echo "$4" | grep "^\s*$" >/dev/null; then
    return 2
  fi

  if [ -z "$1" ] || ! expr "$1" : "^[a-zA-Z][a-zA-Z0-9_]*$" >/dev/null 2>&1 || { [ -n "$2" ] && ! expr "$2" : "^[0-9]\+$" >/dev/null 2>&1; } || { [ -n "$3" ] && expr "$3" : ".*#" >/dev/null 2>&1; } || { [ -n "$4" ] && expr "$4" : ".*#" >/dev/null 2>&1; } || { [ -n "$5" ] && expr "$5" : ".*#" >/dev/null 2>&1; } || { [ -n "$6" ] && [ "$6" != "true" ] && [ "$6" != "false" ]; } || { [ -n "$7" ] && expr "$7" : ".*#" >/dev/null 2>&1; }; then
    return 2
  fi

  if [ -z "${processes}" ]; then
    processes="$1#$2#$3#$4#$5#$6#$7"
  else
    processes="$(echo "${processes}" | awk -F"#" -v SERVICE_NAME="$1" -v PROCESS_ID="$2" -v STOP_COMMAND="$3" -v KILL_COMMAND="$4" -v CHECK_COMMAND="$5" -v IS_GROUPED="$6" -v TMP_RUNNER_FILE="$7" 'BEGIN { found=0 } { if (tolower(SERVICE_NAME) == tolower($1)) { found=1 ; print SERVICE_NAME"#"PROCESS_ID"#"STOP_COMMAND"#"KILL_COMMAND"#"CHECK_COMMAND"#"IS_GROUPED"#"TMP_RUNNER_FILE } else { print $0 } } END { if (!(found)) { print SERVICE_NAME"#"PROCESS_ID"#"STOP_COMMAND"#"KILL_COMMAND"#"CHECK_COMMAND"#"IS_GROUPED"#"TMP_RUNNER_FILE } }')"
  fi
}

# Returns the info of a process registered in the process list
#
# Parameters :
#   - $1 : service name
get_registered_process_info() {
  if [ -z "$1" ] || ! expr "$1" : "^[a-zA-Z][a-zA-Z0-9_]*$" >/dev/null 2>&1; then
    return 2
  fi

  if [ -n "${processes}" ]; then
    check_get_registered_process_info "$(echo "${processes}" | awk -F"#" "{ if (tolower(\"$1\") == tolower(\$1)) { print \$0 } }")"
  else
    return 3
  fi
}

check_get_registered_process_info() {
  if [ -z "$1" ]; then
    return 3
  fi

  echo "$1"
}

# Returns the processes info list
#
# Outputs :
#   Registered processes info list
get_registered_processes_info() {
  printf "%s\n" "${processes}"
}

# Kill a process
#
# Parameters :
#   - $1 : service name
#   - $2 : process ID
#   - $3 : standard kill timeout
#   - $4 : force kill timeout
#   - $5 : indicates if the process should be killed gracefully (true or false)
kill_process() {
  if [ -z "$2" ] || ! expr "$2" : "^-\?[0-9]\+$" >/dev/null 2>&1 || [ -z "$3" ] || ! expr "$3" : "^[0-9]\+$" >/dev/null 2>&1 || [ -z "$4" ] || ! expr "$4" : "^[0-9]\+$" >/dev/null 2>&1 || { [ -n "$5" ] && [ "$5" != "true" ] && [ "$5" != "false" ]; }; then
    return 2
  fi

  if [ "$5" = "true" ]; then
    # Kill the process gracefully and wait for it to stop or kill it by force if it cannot be stopped
    echo "Stopping $1 with PID ${2#-}"

    if ! kill -15 "$2" && ps -p "$2" >/dev/null 2>&1; then
      echo "--> Standard stop failed : force killing $1 with PID ${2#-}" >&2

      if ! kill -9 "$2" && ps -p "$2" >/dev/null 2>&1; then
        echo "Failed to force kill $1 with PID ${2#-}" >&2
        return 10
      else
        if ! wait_for_process_to_stop "$1" "${2#-}" "$4" 2>/dev/null; then
          echo "Failed to wait for $1 with PID ${2#-} to stop" >&2
          return 11
        else
          echo "Force killed $1 with PID ${2#-}"
          return 12
        fi
      fi
    else
      if ! wait_for_process_to_stop "$1" "${2#-}" "$3" 2>/dev/null; then
        echo "--> Standard stop failed : force killing $1 with PID ${2#-}" >&2

        if ! kill -9 "$2" && ps -p "$2" >/dev/null 2>&1; then
          echo "Failed to force kill $1 with PID ${2#-}" >&2
          return 13
        else
          if ! wait_for_process_to_stop "$1" "${2#-}" "$4" 2>/dev/null; then
            echo "Failed to wait for $1 with PID ${2#-} to stop" >&2
            return 14
          else
            echo "Force killed $1 with PID ${2#-}"
            return 15
          fi
        fi
      else
        echo "Stopped $1 with PID ${2#-}"
      fi
    fi
  else
    # Force kill process
    echo "Force killing $1 with PID ${2#-}"

    if ! kill -9 "$2" && ps -p "$2" >/dev/null 2>&1; then
      echo "Failed to force kill $1 with PID ${2#-}" >&2
      return 16
    else
      if ! wait_for_process_to_stop "$1" "${2#-}" "$4" 2>/dev/null; then
        echo "Failed to wait for $1 with PID ${2#-} to stop" >&2
        return 17
      else
        echo "Force killed $1 with PID ${2#-}"
      fi
    fi
  fi
}

##############################################
# Temporary status file management functions #
##############################################

# Reset the status that indicates whether the existence of a temporary runner file has already been checked
#
# Parameters :
#   - $1 : service name
reset_tmp_file_status() {
  if [ -z "$1" ] || ! expr "$1" : "^[a-zA-Z][a-zA-Z0-9_]*$" >/dev/null 2>&1; then
    return 2
  fi

  eval "$(echo "$1" | awk '{ print tolower($0) }')_checked_tmp_runner_file=false"
}

# Wait until a temporary file is created by a runner (and hence ready to be stopped)
#
# Parameters :
#   - $1 : service name
#   - $2 : temporary file name
#   - $3 : associated service process ID
#   - $4 : timeout in seconds
wait_until_tmp_runner_file_exists() {
  if [ -z "$1" ] || ! expr "$1" : "^[a-zA-Z][a-zA-Z0-9_]*$" >/dev/null 2>&1 || [ -z "$2" ] || ! expr "$2" : "^[a-zA-Z][a-zA-Z0-9_]*$" >/dev/null 2>&1 || [ -z "$3" ] || ! expr "$3" : "^-\?[0-9]\+$" >/dev/null 2>&1 || [ -z "$4" ] || ! expr "$4" : "^[0-9]\+$" >/dev/null 2>&1; then
    return 2
  fi

  # Run the checks
  echo "Waiting for $1 to create the ${TMPDIR:-/tmp}/$2 file ($4 seconds) ..."
  safe_wait_until_tmp_runner_file_exists "$1" "$2" "$3" "$4" "$(eval "echo \${$1_checked_tmp_runner_file}")" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"

  if [ -f "${TMPDIR:-/tmp}/$2" ]; then
    rm "${TMPDIR:-/tmp}/$2" || return $?
  fi

  return "${recursive_exit_code:-1}"
}

# Avoid concurrency and interruption problems by using a "safe wait" method
#
# Parameters :
#   - $1...$4 : same parameters
#   - $5 : flag that indicates if the file check has been already executed
#   - $6 : starting Unix timestamp
#   - $7 : current Unix timestamp after sleep
safe_wait_until_tmp_runner_file_exists() {
  if [ "$5" != "true" ]; then
    if [ -z "$6" ]; then # The output of the start timestamp is empty, mainly because the execution of the command has been interrupted: a re-execution of the function is necessary
      safe_wait_until_tmp_runner_file_exists "$1" "$2" "$3" "$4" "$5" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"
    fi

    if [ -z "$7" ]; then # The output of the current timestamp is empty, mainly because the execution of the command has been interrupted: a re-execution of the function is necessary
      safe_wait_until_tmp_runner_file_exists "$1" "$2" "$3" "$4" "$5" "$6" "$(date +%s 2>/dev/null)"
    fi

    # Check process and temporary file existence
    if [ ! -f "${TMPDIR:-/tmp}/$2" ]; then
      if ! check_process_existence "" "${3#-}" 2>/dev/null; then
        echo "$1 has already exited. Skipping." >&2
        eval "$1_checked_tmp_runner_file=true"
        recursive_exit_code=3
        return 3
      fi

      if [ "$(($7 - $6))" -ge "$4" ]; then
        echo "Failed to wait for the existence of the ${TMPDIR:-/tmp}/$2 file. Skipping the check." >&2
        eval "$1_checked_tmp_runner_file=true"
        recursive_exit_code=4
        return 4
      fi

      sleep 1
      safe_wait_until_tmp_runner_file_exists "$1" "$2" "$3" "$4" "$5" "$6" "$(date +%s 2>/dev/null)"
    fi

    recursive_exit_code=$?
    eval "$1_checked_tmp_runner_file=true"

    return "${recursive_exit_code}"
  fi
}

##################
# Core functions #
##################

# Detects the available Docker Compose CLI
#
# Outputs :
#    Available Docker Compose CLI command (if available)
detect_docker_compose_cli() {
  # Check if Docker Compose is installed and that the Docker daemon is running
  if docker info >/dev/null 2>&1; then
    if docker compose version 2>/dev/null; then
      echo "docker compose"
    elif docker-compose version 2>/dev/null; then
      echo "docker-compose"
    else
      return 127
    fi
  else
    return 127
  fi

}

# Detect a compatible and available version of Docker Compose CLI installed on the system
#
# Outputs :
#   Detected java system stack (Docker Compose CLI:Version) if available
detect_compatible_available_docker_compose_cli() {
  docker_detection_error=false
  docker_detection_system_error=false
  docker_compose_cli=

  # Check if Docker Compose is installed and that the Docker daemon is running
  if docker info >/dev/null 2>&1; then
    if docker_compose_version="$(docker compose version 2>/dev/null)"; then
      docker_compose_cli="docker compose"
    elif docker_compose_version="$(docker-compose version 2>/dev/null)"; then
      docker_compose_cli="docker-compose"
    else
      docker_detection_error=true
      docker_detection_system_error=true
    fi
  else
    docker_detection_error=true
    docker_detection_system_error=true
  fi

  if ${docker_detection_error} || ${docker_detection_system_error}; then
    docker_compose_cli=
    docker_compose_version=

    if ${docker_detection_system_error}; then
      return 126
    else
      return 127
    fi
  fi

  if [ -n "${docker_compose_cli}" ] && docker_compose_version="$(echo "${docker_compose_version}" | sed -n 's/^[^0-9]*\([0-9]\+\)\.\([0-9]\+\)\.\{0,1\}\([0-9]\+\)\{0,1\}.*$/\1.\2.\3/p' | awk -F"." "${AWK_REQUIRED_DOCKER_COMPOSE_VERSION}")" && [ -n "${docker_compose_version}" ]; then
    echo "${docker_compose_cli}:${docker_compose_version}"
  else
    docker_detection_error=true
    docker_compose_cli=
    docker_compose_version=

    return 127
  fi
}

# Detect a compatible and available version of Java CLI installed on the system
#
# Outputs :
#   Detected Java system stack (java:Version) if available
detect_compatible_available_java_cli() {
  if ! java_version="$(java -version 2>&1)"; then
    java_cli=
    java_version=

    return 126
  fi

  if java_version="$(printf "%s" "${java_version}" | head -n 1 | sed -n 's/^[^0-9]*\([0-9]\+\)\.\([0-9]\+\)\.\{0,1\}\([0-9]\+\)\{0,1\}.*$/\1.\2.\3/p' | awk -F"." "${AWK_REQUIRED_JAVA_VERSION}")" && [ -n "${java_version}" ]; then
    java_cli="java"

    echo "${java_cli}:${java_version}"
  else
    java_cli=
    java_version=

    return 127
  fi
}

# Detect a compatible and available version of Maven CLI installed on the system
#
# Outputs :
#   Detected Maven system stack (maven:Version) if available
detect_compatible_available_maven_cli() {
  if ! maven_version="$(mvn -version 2>/dev/null)"; then
    maven_cli=
    maven_version=

    return 126
  fi

  if maven_version="$(printf "%s" "${maven_version}" | head -n 1 | sed -n 's/^[^0-9]*\([0-9]\+\)\.\([0-9]\+\)\.\{0,1\}\([0-9]\+\)\{0,1\}.*$/\1.\2.\3/p' | awk -F"." "${AWK_REQUIRED_MAVEN_VERSION}")" && [ -n "${maven_version}" ]; then
    maven_cli="maven"

    echo "${maven_cli}:${maven_version}"
  else
    maven_cli=
    maven_version=

    return 127
  fi
}

# Detect a compatible and available version of Node CLI installed on the system
#
# Outputs :
#   Detected Node system stack (node:Version) if available
detect_compatible_available_node_cli() {
  if ! node_version="$(node -v 2>/dev/null)"; then
    node_cli=
    node_version=

    return 126
  fi

  if node_version="$(printf "%s" "${node_version}" | sed -n 's/^[^0-9]*\([0-9]\+\)\.\([0-9]\+\)\.\{0,1\}\([0-9]\+\)\{0,1\}.*$/\1.\2.\3/p' | awk -F"." "${AWK_REQUIRED_NODE_VERSION}")" && [ -n "${node_version}" ]; then
    node_cli="node"

    echo "${node_cli}:${node_version}"
  else
    node_cli=
    node_version=

    return 127
  fi
}

# Automatically choose the environment mode based on the available system stack
auto_detect_system_stack() {
  echo "Auto-choosing the launch method ..."

  # Check if Docker Compose is installed and that the Docker daemon is running
  if detect_compatible_available_docker_compose_cli >/dev/null 2>&1; then
    echo "Docker Compose (${docker_compose_cli}) version ${docker_compose_version}"

    environment="${DOCKER_ENVIRONMENT}"
  elif detect_compatible_available_java_cli >/dev/null 2>&1 && detect_compatible_available_maven_cli >/dev/null 2>&1 && detect_compatible_available_node_cli >/dev/null 2>&1; then # Fallback: check if the installed versions of Java and Node are compatible
    echo "Java version ${java_version}"
    echo "Maven version ${maven_version}"
    echo "Node version ${node_version}"

    environment="${SYSTEM_ENVIRONMENT}"
  else
    environment=false
  fi

  if [ "${environment}" = "false" ]; then
    echo "Unable to run the demo" >&2
    echo "${REQUIREMENTS_TEXT}" >&2
    return 127
  fi
}

# Checks if a file exists
# Parameters :
#   - $1 : file or directory (-f / -d)
#   - $2 : file path
check_file_existence() {
  { [ "$1" = "-f" ] && [ -f "$2" ]; } || { [ "$1" = "-d" ] && [ -d "$2" ]; }
}

# Checks if load-balancing related packages are build on the system
check_load_balancing_packages() {
  check_file_existence -f ldconfig/target/ldconfig.jar &&
    check_file_existence -f ldservice/target/ldservice.jar &&
    check_file_existence -d ldfront/node_modules &&
    check_file_existence -f lddiscovery/target/lddiscovery.jar &&
    check_file_existence -f ldloadbalancer/target/ldloadbalancer.jar
}

# Checks if load-balancing related packages are build on the system
check_no_load_balancing_packages() {
  check_file_existence -f ldconfig/target/ldconfig.jar &&
    check_file_existence -f ldservice/target/ldservice.jar &&
    check_file_existence -d ldfront/node_modules
}

# Read environment variables and auto-configure some variables related to the Git / DNS environment
configure_environment_variables() {
  cd_to_script_dir "run.sh" "spring-load-balancing-demo" || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"

  if ${start}; then
    echo "Reading environment variables ..."

    if [ "${mode}" = "${LOAD_BALANCING_MODE}" ]; then
      environment_file=.env
    else
      environment_file=no-load-balancing.env
    fi

    if read_environment_file "${environment_file}"; then
      echo "Environment auto-configuration ..."

      if ! GIT_CONFIG_BRANCH="$(git rev-parse --abbrev-ref HEAD)"; then
        GIT_CONFIG_BRANCH=master
      fi

      if ! LOADBALANCER_HOSTNAME="$(hostname)"; then
        LOADBALANCER_HOSTNAME=localhost
      fi

      export GIT_CONFIG_BRANCH
      export LOADBALANCER_HOSTNAME
      export API_HOSTNAME="${LOADBALANCER_HOSTNAME}"
      export API_TWO_HOSTNAME="${LOADBALANCER_HOSTNAME}"

      if [ "${environment}" = "${SYSTEM_ENVIRONMENT}" ]; then # System-dependent servers settings
        export CONFIG_SERVER_URL="http://localhost:${CONFIG_SERVER_PORT}"

        if [ "${mode}" = "${LOAD_BALANCING_MODE}" ]; then
          export EUREKA_SERVERS_URLS="http://localhost:${DISCOVERY_SERVER_PORT}/eureka"
        else
          unset EUREKA_SERVERS_URLS
        fi

        unset DB_URL
        unset DB_USERNAME
        unset DB_PASSWORD
        unset DB_PORT
      fi
    else
      return $?
    fi
  fi
}

# Build demo packages
build() {
  cd_to_script_dir "run.sh" "spring-load-balancing-demo" || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"

  if [ "${environment}" -eq "${DOCKER_ENVIRONMENT}" ] && ${build}; then
    echo "Building packages and images ..."

    if [ "${mode}" -eq "${LOAD_BALANCING_MODE}" ]; then
      eval_script "${docker_compose_cli} build" || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
    else
      eval_script "${docker_compose_cli} -f docker-compose-no-load-balancing.yml build" || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
    fi
  else
    if ! ${build} && [ "${environment}" -eq "${SYSTEM_ENVIRONMENT}" ]; then
      if ${start} && [ "${mode}" -eq "${LOAD_BALANCING_MODE}" ] && ! check_load_balancing_packages; then
        echo "Load Balancing packages are not completely built. Build mode enabled." >&2
        build=true
      fi

      if ${start} && [ "${mode}" -eq "${NO_LOAD_BALANCING_MODE}" ] && ! check_no_load_balancing_packages; then
        echo "No Load Balancing packages are not completely built. Build mode enabled." >&2
        build=true
      fi
    fi

    if ${build} && [ "${environment}" -eq "${SYSTEM_ENVIRONMENT}" ]; then
      echo "Building packages ..."
      mvn clean package -T 3 -DskipTests -DfinalName=ldconfig -f ldconfig/pom.xml || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
      mvn clean package -T 3 -DskipTests -DfinalName=ldservice -f ldservice/pom.xml || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"

      if [ "${mode}" -eq "${LOAD_BALANCING_MODE}" ]; then
        mvn clean package -T 3 -DskipTests -DfinalName=lddiscovery -f lddiscovery/pom.xml || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
        mvn clean package -T 3 -DskipTests -DfinalName=ldloadbalancer -f ldloadbalancer/pom.xml || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
      fi

      cd ldfront || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
      npm install || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
      cd .. || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
    fi
  fi
}

# Starts Docker Compose services and isolates the daemon
# Parameters :
#   - $@ : parameters to pass to Docker Compose
# shellcheck disable=SC2016
# shellcheck disable=SC2086
# shellcheck disable=SC2154
start_docker_compose_services() {
  # Project name passed to the function
  if [ -n "${project_name}" ]; then
    project_argument="-p ${project_name}"
  fi

  # Start containers or stop them in the event of an error
  while ! block_exit; do true; done
  ${docker_compose_cli} "$@" -d || {
    start_error=$?
    while ! release_exit; do true; done

    ${docker_compose_cli} ${project_argument} stop -t 20 || {
      while ! block_exit; do true; done
      ${docker_compose_cli} ${project_argument} kill
    }

    cleanup ${start_error} "${AUTOMATED_CLEANUP}" "${cleanup_count}"
    return "${exit_code}"
  }

  # Show the services output and stop them when CTRL-C is triggered
  while ! release_exit; do true; done
  ${docker_compose_cli} "$@"
  
  ${docker_compose_cli} ${project_argument} stop -t 20 || { 
    while ! block_exit; do true; done
    ${docker_compose_cli} ${project_argument} kill
  } || {
    cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
    return "${exit_code}"
  }

  cleanup 130 "${AUTOMATED_CLEANUP}" "${cleanup_count}"
}

# Starts a Java process
# Parameters :
#   - $@ : parameters to pass to the Java CLI
# shellcheck disable=SC2016
# shellcheck disable=SC2154
start_java_process() {
  java "$@" &
}

# Starts a npm process
# Parameters :
#   - $@ : parameters to pass to the npm CLI
# shellcheck disable=SC2016
# shellcheck disable=SC2154
start_npm_process() {
  (
    trap '' INT
    echo n | npm "$@"
  ) &
}

# Start the demo
# shellcheck disable=SC2016
# shellcheck disable=SC2154
start() {
  cd_to_script_dir "run.sh" "spring-load-balancing-demo" || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"

  if ${start}; then
    start_error=0
    block_exit || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"

    if [ "${environment}" -eq "${DOCKER_ENVIRONMENT}" ]; then # Docker environment
      while ! queue_exit; do true; done

      echo "Launching Docker services ..."

      # Start the services
      if [ "${mode}" -eq "${LOAD_BALANCING_MODE}" ]; then
        project_name="ldloadbalancing-enabled" start_docker_compose_services up
      else
        project_name="ldloadbalancing-disabled" start_docker_compose_services -f docker-compose-no-load-balancing.yml --env-file no-load-balancing.env up
      fi
    else # System-dependent environment
      while ! queue_exit; do true; done

      # Configure the front service environment variables
      echo "FRONT_SERVER_PORT=${FRONT_SERVER_PORT}" >ldfront/.env
      echo "API_URL=${API_URL}" >>ldfront/.env
      ldfront_tmp_runner_file="ldfront_$$_$(random_number 9999)"
      echo "TMP_RUNNER_FILE=${ldfront_tmp_runner_file}" >>ldfront/.env
      touch "${TMPDIR:-/tmp}/${ldfront_tmp_runner_file}" || true

      # Disable the cleanup function until all processes have started : register the signal to handle it later
      echo "Launching services ..."

      # Start processes
      while ! block_exit; do true; done

      start_java_process -XX:TieredStopAtLevel=1 -Dspring.config.location=file:./ldconfig/src/main/resources/application.properties -jar "$(pwd)/ldconfig/target/ldconfig.jar"
      LdConfig_pid=$!

      start_java_process -XX:TieredStopAtLevel=1 -Dspring.config.location=file:./ldservice/src/main/resources/application.properties -jar "$(pwd)/ldservice/target/ldservice.jar"
      LdServiceOne_pid=$!

      if [ "${mode}" -eq "${LOAD_BALANCING_MODE}" ]; then
        start_java_process -XX:TieredStopAtLevel=1 -Dspring.config.location=file:./ldservice/src/main/resources/application.properties -DAPI_SERVER_PORT="${API_TWO_SERVER_PORT}" -DAPI_HOSTNAME="${API_TWO_HOSTNAME}" -jar "$(pwd)/ldservice/target/ldservice.jar"
        LdServiceTwo_pid=$!

        start_java_process -XX:TieredStopAtLevel=1 -Dspring.config.location=file:./ldloadbalancer/src/main/resources/application.properties -jar "$(pwd)/ldloadbalancer/target/ldloadbalancer.jar"
        LdLoadbalancer_pid=$!

        start_java_process -XX:TieredStopAtLevel=1 -Dspring.config.location=file:./lddiscovery/src/main/resources/application.properties -jar "$(pwd)/lddiscovery/target/lddiscovery.jar"
        LdDiscovery_pid=$!
      fi

      cd ldfront || start_error=$?
      start_npm_process run start
      LdFront_pid=$!

      # Register the processes info
      register_process_info "LdConfig" "${LdConfig_pid}" "" "" "" false
      register_process_info "LdServiceOne" "${LdServiceOne_pid}" "" "" "" false
      register_process_info "LdServiceTwo" "${LdServiceTwo_pid}" "" "" "" false
      register_process_info "LdLoadbalancer" "${LdLoadbalancer_pid}" "" "" "" false
      register_process_info "LdDiscovery" "${LdDiscovery_pid}" "" "" "" false
      register_process_info "LdFront" "${LdFront_pid}" "" "" "" true "${ldfront_tmp_runner_file}"

      while ! queue_exit; do true; done

      # Wait until all processes have started
      while IFS="#" read -r SERVICE_NAME PID STOP_COMMAND KILL_COMMAND CHECK_COMMAND IS_GROUPED TMP_RUNNER_FILE; do
        if [ -n "${PID}" ]; then
          wait_for_process_to_start "${SERVICE_NAME}" "${PID}" 5 || start_error=$?
        fi
      done <<EOF
$(get_registered_processes_info)
EOF

      # A process error occurred
      if [ "${start_error}" -ne 0 ]; then
        cleanup "${start_error}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
        return "${exit_code}"
      fi

      # Check if there is at least one service started to enter the check loop
      found_started_service=false
      while IFS="#" read -r SERVICE_NAME PID STOP_COMMAND KILL_COMMAND CHECK_COMMAND IS_GROUPED TMP_RUNNER_FILE; do
        if [ -n "${SERVICE_NAME}" ]; then
          found_started_service=true
          break
        fi
      done <<EOF
$(get_registered_processes_info)
EOF

      # No services were started
      if ! ${found_started_service}; then
        cleanup 3 "${AUTOMATED_CLEANUP}" "${cleanup_count}"
        return "${exit_code}"
      fi

      # Loop through processes and exit if any has exited
      while true; do
        # A pending user cleanup signal was triggered
        if is_waiting_for_cleanup; then
          cleanup "${queued_signal_code}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
          break
        fi

        while IFS="#" read -r SERVICE_NAME PID STOP_COMMAND KILL_COMMAND CHECK_COMMAND IS_GROUPED TMP_RUNNER_FILE; do
          if [ -n "${SERVICE_NAME}" ]; then
            check_process_existence "${CHECK_COMMAND}" "${PID}" || {
              cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
              break
            }
          fi

          sleep 1 &
          wait $!
        done <<EOF
$(get_registered_processes_info)
EOF
      done
    fi
  fi

  return "${exit_code}"
}

#############################
# Cleanup related functions #
#############################

# Returns if the script is waiting for a cleanup
#
# Parameters :
#   - $1 : local cleanup count
is_waiting_for_cleanup() {
  if [ -n "$1" ]; then
    if [ "$1" != "${cleanup_count}" ]; then
      return 0
    fi
  elif [ "${queued_signal_code}" -ge 1 ]; then
    return 0
  fi

  return 1
}

# Invoke a graceful service cleanup script if standard shutdown signal handling fails
#
# Parameters :
#    - $1 : name of the service on which a graceful cleanup script should be invoked
invoke_graceful_service_cleanup() {
  error=false

  case $1 in
  LdFront)
    # Remove the line concerning the temporary runner file
    if ! sed -i"" "/TMP_RUNNER_FILE/d" ldfront/.env >/dev/null 2>&1; then
      echo "Failed to remove the TMP_RUNNER_FILE key from the .env environment file" >&2
      error=true
    fi

    # Remove temporary JavaScript environment file to avoid conflicts with Docker
    if [ -f ldfront/src/assets/environment.js ]; then
      echo "Removing temporary JavaScript file src/assets/environment.js"

      if ! rm ldfront/src/assets/environment.js 2>/dev/null; then
        echo "Failed to remove the src/assets/environment.js temporary JavaScript environment file" >&2
        error=true
      fi
    fi

    # Remove the temporary runner files
    if [ -f "${TMPDIR:-/tmp}/${ldfront_tmp_runner_file}" ]; then
      rm "${TMPDIR:-/tmp}/${ldfront_tmp_runner_file}" 2>/dev/null
    fi
    ;;
  esac

  if ${error}; then
    return 1
  fi
}

# Cleanup the environment (process, environment variables, temporary files)
#
# Parameters :
#   - $1 : retrieved exit code
#   - $2 : cleanup mode
#   - $3 : local cleanup count
cleanup() {
  set +e

  # Update exit code
  if [ "$1" != "0" ]; then
    exit_code="$1"
  fi

  # Cleanup counter increment
  if [ "$2" = "${USER_CLEANUP}" ]; then
    cleanup_count=$((cleanup_count + 1))
  elif [ "$2" = "${QUEUED_USER_CLEANUP}" ]; then
    if [ "$1" = "130" ] && ! ${enabled_sigint_code}; then
      queued_signal_code=130
      exit_code=130
      enabled_sigint_code=true
    fi

    if [ "$1" = "143" ] && ! ${enabled_sigterm_code}; then
      queued_signal_code=143
      exit_code=143
      enabled_sigterm_code=true
    fi

    if [ "${queued_signal_code}" = "-1" ] || { [ "$1" != "130" ] && [ "$1" != "143" ]; }; then
      queued_signal_code="$1"
      exit_code="$1"
    fi

    cleanup_count=$((cleanup_count + 1))
    return_script
    return
  fi

  if ! ${cleanup_executed}; then
    # Restore directory location
    if [ -n "$(pwd | awk '/ldfront[\/\\]?$/ { print }' 2>/dev/null)" ]; then
      cd ..
    fi

    # Processes cleanup
    while IFS="#" read -r SERVICE_NAME PID STOP_COMMAND KILL_COMMAND CHECK_COMMAND IS_GROUPED TMP_RUNNER_FILE; do
      # Although concurrency is not really an issue here, it is best to avoid sending two different signals at almost the same time, so we restart the cleaning function if an exit signal has been triggered again
      if is_waiting_for_cleanup "$3"; then
        cleanup "${queued_signal_code}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
      fi

      if [ -n "${SERVICE_NAME}" ]; then
        while ! block_exit; do true; done

        # The process may be decomposed into multiple processes (a group of processes)
        if ${process_control_enabled} && [ "${IS_GROUPED}" = "true" ]; then
          PID="-${PID}"
        fi

        # Wait until the application is really started by detecting the presence of a temporary file (if the process is decomposed into multiple processes and a start check is required)
        if check_process_existence "${CHECK_COMMAND}" "${PID#-}" 2>/dev/null; then
          while ! queue_exit; do true; done

          if [ -n "${TMP_RUNNER_FILE}" ] && ! wait_until_tmp_runner_file_exists "${SERVICE_NAME}" "${TMP_RUNNER_FILE}" "${PID}" 15; then
            exit_code=17
          fi
        fi

        # Try to stop the process gracefully before trying to force kill it
        if [ -n "${PID}" ]; then
          while ! block_exit; do true; done

          if check_process_existence "" "${PID#-}" 2>/dev/null; then
            while ! queue_exit; do true; done

            if [ ${cleanup_count} -le 1 ]; then # Default kill
              kill_process "${SERVICE_NAME}" "${PID#-}" 20 8 true || exit_code=$?
            else # Force kill
              kill_process "${SERVICE_NAME}" "${PID#-}" 20 8 false || exit_code=$?
            fi
          fi
        fi

        # Custom stop command
        if [ -n "${STOP_COMMAND}" ] || [ -n "${KILL_COMMAND}" ]; then
          while ! block_exit; do true; done

          if [ ${cleanup_count} -le 1 ] && [ -n "${STOP_COMMAND}" ]; then # Default kill
            eval_script "${STOP_COMMAND}" &
            wait $! || exit_code=$?
          elif { [ ${cleanup_count} -gt 1 ] || [ -z "${STOP_COMMAND}" ] && [ -n "${KILL_COMMAND}" ]; } || { [ ${cleanup_count} -gt 1 ] && [ -n "${KILL_COMMAND}" ]; }; then # Force kill
            eval_script "${KILL_COMMAND}" &
            wait $! || exit_code=$?
          fi

          while ! queue_exit; do true; done
        fi

        # Perform graceful service cleanup
        invoke_graceful_service_cleanup "${SERVICE_NAME}"
      fi

      while ! queue_exit; do true; done

      if is_waiting_for_cleanup "$3"; then
        cleanup "${exit_code}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
      fi
    done <<EOF
$(get_registered_processes_info)
EOF

    while ! queue_exit; do true; done

    # Wait for all processes to terminate in case of error, do not exit immediately. Allow another attempt.
    if [ -n "${processes}" ]; then
      echo "Waiting for processes to shut down ..."
      echo "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
    fi

    while ! wait || ! (
      code=$?
      if [ ${code} -eq 130 ] || [ ${code} -eq 143 ]; then exit 1; else exit 0; fi
    ) || ! (
      while IFS="#" read -r SERVICE_NAME PID STOP_COMMAND KILL_COMMAND CHECK_COMMAND IS_GROUPED TMP_RUNNER_FILE; do
        if check_process_existence "${CHECK_COMMAND}" "${PID#-}" 2>/dev/null; then
          exit 1
        fi
      done <<EOF
$(get_registered_processes_info)
EOF
      exit
    ) || ! (
      code=$?
      if [ ${code} -eq 130 ] || [ ${code} -eq 143 ]; then exit 1; else exit 0; fi
    ); do
      if is_waiting_for_cleanup "$3"; then
        cleanup "${exit_code}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
      fi

      sleep 1 &
      wait $!
    done
    cleanup_executed=true
  fi

  exit_script "${exit_code}"
}

##################
# Main functions #
##################

# Prevent the script from terminating in certain states and save the output signals to handle them later
block_exit() {
  set +e
  trap '' INT TERM
  { stty_settings="$(stty -g 2>/dev/null)" && stty intr '' 2>/dev/null; } || true
}

# Queue the output signals to wait for the script to start gracefully before cleaning up
queue_exit() {
  set +e
  trap 'cleanup 130 "${QUEUED_USER_CLEANUP}"' INT
  trap 'cleanup 143 "${QUEUED_USER_CLEANUP}"' TERM

  if [ -n "${stty_settings}" ]; then
    stty "${stty_settings}" 2>/dev/null || true
  fi
}

# Allow the script to exit again
unblock_exit() {
  trap 'cleanup 130 "${USER_CLEANUP}"' INT
  trap 'cleanup 143 "${USER_CLEANUP}"' TERM
  trap 'cleanup $? "${AUTOMATED_CLEANUP}"' EXIT

  if [ -n "${stty_settings}" ]; then
    stty "${stty_settings}" 2>/dev/null || true
  fi
}

release_exit() {
  trap 'true' INT
  trap 'true' TERM
  trap 'true' EXIT

  if [ -n "${stty_settings}" ]; then
    stty "${stty_settings}" 2>/dev/null || true
  fi
}

# Eval from a function (allows to mock the function)
#
# Parameters :
#   - $1 : command
# shellcheck disable=SC2120
eval_script() {
  eval "$1"
}

# Returns from a function (allows to mock the function)
#
# Parameters :
#   - $1 : return code
# shellcheck disable=SC2120
return_script() {
  return "${1:-0}"
}

# Exits the script (allows to mock the function)
#
# Parameters :
#   - $1 : exit code
exit_script() {
  exit "${1:-0}"
}

# Initialize the shell parameters
# shellcheck disable=SC2039
# shellcheck disable=SC3041
init_shell_params() {
  unblock_exit || exit $?

  set +H 2>/dev/null
  set -m 2>/dev/null && process_control_enabled=true
  set -e
}

# Run the load-balancing demo given the passed run arguments
# --no-start : don't start the demo
# --no-build : don't build the packages when starting the demo. If some packages are missing, the build will be automatically enabled.
# --no-load-balancing : because of the demo intent, the load balancing is enabled by default
# --load-core-only : don't run the demo at all. Useful for testing.
# shellcheck disable=SC2016
main() {
  # Versions related flags
  AWK_REQUIRED_DOCKER_COMPOSE_VERSION='{ if (($1 > 1) || (($1 == 1) && ($2 >= 29))) { if ($3 != "") { print $1"."$2"."$3 } else { print $1"."$2".0" } } }'
  AWK_REQUIRED_JAVA_VERSION='{ if ($1 >= 17) { if ($3 != "") { print $1"."$2"."$3 } else { print $1"."$2".0" } } }'
  AWK_REQUIRED_MAVEN_VERSION='{ if (($1 > 3) || (($1 == 3) && ($2 >= 5))) { if ($3 != "") { print $1"."$2"."$3 } else { print $1"."$2".0" } } }'
  AWK_REQUIRED_NODE_VERSION='{ if ($1 >= 16) { if ($3 != "") { print $1"."$2"."$3 } else { print $1"."$2".0" } } }'
  REQUIREMENTS_TEXT="Required : Docker Compose >= 1.29 or Java >= 17 with Maven >= 3.5 and Node >= 16"

  # Demo deployment modes
  LOAD_BALANCING_MODE=1
  NO_LOAD_BALANCING_MODE=2
  DOCKER_ENVIRONMENT=1
  SYSTEM_ENVIRONMENT=2

  # Default mode : run with Docker (Load Balancing)
  mode=${LOAD_BALANCING_MODE}
  environment=${DOCKER_ENVIRONMENT}
  build=true
  start=true
  process_control_enabled=false

  if [ "${load_core_only}" != "true" ] && [ "${load_core_only}" != "false" ]; then
    load_core_only=false
  fi

  # Graceful cleanup flags
  cleanup_count=0
  exit_code=0
  queued_signal_code=-1
  cleanup_executed=false
  enabled_sigint_code=false
  enabled_sigterm_code=false

  # Cleanup signals modes
  AUTOMATED_CLEANUP=1
  USER_CLEANUP=2
  QUEUED_USER_CLEANUP=3

  # Parse run arguments
  for arg in "$@"; do
    case "${arg}" in
    --no-start) start=false ;;
    --no-build) build=false ;;
    --no-load-balancing) mode=${NO_LOAD_BALANCING_MODE} ;;
    --load-core-only) load_core_only=true ;;
    esac
  done

  # Execute if not sourced
  if ! ${load_core_only}; then
    if ! ${build} && ! ${start}; then
      exit_script
    fi

    run
  fi
}

run() {
  # Initialize the shell parameters to handle the script in good conditions (exit / cleanup on error, separate process groups)
  init_shell_params &&

    # Auto-choose the launch / environment method
    auto_detect_system_stack &&

    # Read and configure environment variables
    configure_environment_variables &&

    # Build demo packages
    build &&

    # Ready : start the demo !
    start
}

main "$@"
