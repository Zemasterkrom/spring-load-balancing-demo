#!/usr/bin/env sh
set -e

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

    while IFS='=' read -r KEY VALUE; do
      if [ -n "${KEY}" ]; then
        export "${KEY}"="${VALUE}"
        ENVIRONMENT_FILE_KEYS="${ENVIRONMENT_FILE_KEYS}${KEY} "
      fi
    done <<EOF
$(
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
    )
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

# Change the process check strategy
#
# Parameters:
# - $1: if this parameter is equal to 1, then processes will be checked using the process ID and the process start time. If none, all information about the process will be retrieved.
set_process_check_existence_strategy() {
  if [ -z "$1" ] || [ "$1" = "1" ]; then
    ps_stime_column_index=$(ps -p 1 -f 2>/dev/null | awk 'NR==1 { for (i = 1; i <= NF; i++) { if ($i == "STIME") { print i } } }' 2>/dev/null)
  else
    ps_stime_column_index=
  fi

  ps_check_strategy_set=true
}

# Returns the current process check strategy
#
# Outputs :
#   Strategy number (0 = default, 1 = stime)
get_process_check_existence_strategy() {
  if [ -z "${ps_stime_column_index}" ]; then
    echo 0
  else
    echo 1
  fi
}

is_process_check_existence_strategy_set() {
  if [ -n "${ps_check_strategy_set}" ]; then
    return 0
  else
    return 1
  fi
}

# Returns information about the process according to the chosen process check strategy
#
# Parameters :
#   - $1 : process ID
#
# Outputs:
#   Information about the process according to the chosen process check strategy
get_process_info() {
  check_return_process_info() {
    if [ -z "$1" ]; then
      return 3
    fi

    echo "$1"
  }

  if [ -z "$1" ] || ! expr "$1" : "^[0-9]\+$" >/dev/null 2>&1; then
    return 2
  fi

  # Return process information according to the existence control strategy
  if [ "$(get_process_check_existence_strategy)" = "1" ]; then
    check_return_process_info "$(ps -p "$1" -f 2>/dev/null | awk "(NR>1){ if (!(match(\$${ps_stime_column_index}, /['\"\`\$]/))) { print \$${ps_stime_column_index} } }")"
  else
    check_return_process_info "$(ps -p "$1" 2>/dev/null | sed -n 2p)"
  fi
}

# Check the consistency of the processes to avoid killing the wrong processes
#
# Parameters :
#   - $1 : registered process PID
#   - $2 : registered process start time. Optional.
#
# Outputs :
#   Process information if available
check_process_existence() {
  if [ -z "$1" ] || ! expr "$1" : "^[0-9]\+$" >/dev/null 2>&1; then
    return 2
  fi

  # Check if process is still alive
  if [ "$(get_process_check_existence_strategy)" = "1" ]; then
    if { [ -n "$2" ] && [ "$2" != "$(get_process_info "$1")" ]; } || { [ -z "$2" ] && [ -z "$(get_process_info "$1")" ]; }; then
      return 3
    fi
  elif [ -z "$(get_process_info "$1")" ]; then
    return 3
  fi
}

# Wait for a process to start
#
# Parameters :
#   - $1 : service name
#   - $2 : process ID
#   - $3 : timeout in seconds
wait_for_process_to_start() {
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

    if [ "$(get_process_check_existence_strategy)" = "1" ]; then # STIME check
      eval "$1_stime='$(get_process_info "$2")'"

      if [ -z "$(eval "echo \"\${$1_stime}\"")" ]; then
        if [ "$((${5:-0} - ${4:-0}))" -ge "$3" ]; then
          echo "$1 with PID $2 has not started. Cannot continue." >&2
          return 3
        fi
      else
        return 0
      fi
    else # Default check
      if [ -z "$(get_process_info "$2")" ]; then
        if [ "$(($5 - $4))" -ge "$3" ]; then
          echo "$1 with PID $2 has not started. Cannot continue." >&2
          return 3
        fi
      else
        return 0
      fi
    fi

    # Sleep and update timestamp data
    sleep 1
    safe_wait_for_process_to_start "$1" "$2" "$3" "$4" "$(date +%s 2>/dev/null)"
  }

  if [ -z "$1" ] || ! expr "$1" : "^[a-zA-Z][a-zA-Z0-9_]*$" >/dev/null 2>&1 || [ -z "$2" ] || ! expr "$2" : "^[0-9]\+$" >/dev/null 2>&1 || [ -z "$3" ] || ! expr "$3" : "^[0-9]\+$" >/dev/null 2>&1; then
    return 2
  fi

  # Run the checks
  echo "Waiting for $1 with PID $2 to start ... Please wait ..."
  safe_wait_for_process_to_start "$1" "$2" "$3" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"
}

# Wait for a process to stop
#
# Parameters :
#   - $1 : service name
#   - $2 : process ID
#   - $3 : process start time
#   - $4 : timeout in seconds
wait_for_process_to_stop() {
  # Avoid concurrency and interruption problems by using a "safe wait" method
  #
  # Parameters :
  #   - $1...$4 : same parameters
  #   - $5 : starting Unix timestamp
  #   - $6 : current Unix timestamp after sleep
  safe_wait_for_process_to_stop() {
    if [ -z "${5%% }" ]; then # The output of the start timestamp is empty, mainly because the execution of the command has been interrupted: a re-execution of the function is necessary
      safe_wait_for_process_to_stop "$1" "$2" "$3" "$4" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"
    fi

    if [ -z "${6%% }" ]; then # The output of the current timestamp is empty, mainly because the execution of the command has been interrupted: a re-execution of the function is necessary
      safe_wait_for_process_to_stop "$1" "$2" "$3" "$4" "$5" "$(date +%s 2>/dev/null)"
    fi

    # Check the process existence
    if check_process_existence "$2" "$3" 2>/dev/null; then
      if [ "$(($6 - $5))" -ge "$4" ]; then
        echo "Wait timeout exceeded for $1 with PID $2" >&2
        return 3
      fi
    else
      return 0
    fi

    # Sleep and update timestamp data
    sleep 1
    safe_wait_for_process_to_stop "$1" "$2" "$3" "$4" "$5" "$(date +%s 2>/dev/null)"
  }

  if [ -z "$2" ] || ! expr "$2" : "^[0-9]\+$" >/dev/null 2>&1 || [ -z "$4" ] || ! expr "$4" : "^[0-9]\+$" >/dev/null 2>&1; then
    return 2
  fi

  # Run the checks
  echo "Waiting for $1 with PID $2 to stop ($4 seconds) ..."
  safe_wait_for_process_to_stop "$1" "$2" "$3" "$4" "$(date +%s 2>/dev/null)" "$(date +%s 2>/dev/null)"
}

# Kill a process
#
# Parameters :
#   - $1 : service name
#   - $2 : process ID
#   - $3 : process start time
#   - $4 : standard kill timeout
#   - $5 : force kill timeout
#   - $6 : indicates if the process should be killed gracefully (true or false)
kill_process() {
  if [ -z "$2" ] || ! expr "$2" : "^-\?[0-9]\+$" >/dev/null 2>&1 || [ -z "$4" ] || ! expr "$4" : "^[0-9]\+$" >/dev/null 2>&1 || [ -z "$5" ] || ! expr "$5" : "^[0-9]\+$" >/dev/null 2>&1 || { [ -n "$6" ] && [ "$6" != "true" ] && [ "$6" != "false" ]; }; then
    return 2
  fi

  if [ "$6" = "true" ]; then
    # Kill the process gracefully and wait for it to stop or kill it by force if it cannot be stopped
    echo "Stopping $1 with PID ${2#-}" >&2

    if ! kill -15 "$2" >/dev/null 2>&1; then
      echo "--> Standard stop failed : force killing $1 with PID ${2#-}" >&2

      if ! kill -9 "$2" >/dev/null 2>&1; then
        echo "Failed to force kill $1 with PID ${2#-}" >&2
        return 10
      else
        if ! wait_for_process_to_stop "$1" "${2#-}" "$3" "$5" 2>/dev/null; then
          echo "Failed to wait for $1 with PID ${2#-} to stop" >&2
          return 11
        else
          echo "Force killed $1 with PID ${2#-}"
          return 12
        fi
      fi
    else
      if ! wait_for_process_to_stop "$1" "${2#-}" "$3" "$4" 2>/dev/null; then
        echo "--> Standard stop failed : force killing $1 with PID ${2#-}" >&2

        if ! kill -9 "$2" >/dev/null 2>&1; then
          echo "Failed to force kill $1 with PID ${2#-}" >&2
          return 13
        else
          if ! wait_for_process_to_stop "$1" "${2#-}" "$3" "$5" 2>/dev/null; then
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

    if ! kill -9 "$2" >/dev/null 2>&1; then
      echo "Failed to force kill $1 with PID ${2#-}" >&2
      return 16
    else
      if ! wait_for_process_to_stop "$1" "${2#-}" "$3" "$5" 2>/dev/null; then
        echo "Failed to wait for $1 with PID ${2#-} to stop" >&2
        return 17
      else
        echo "Force killed $1 with PID ${2#-}"
      fi
    fi
  fi
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

# Cleanup the environment (process, environment variables, temporary files)
#
# Parameters :
#   - $1 : retrieved exit code
#   - $2 : boolean flag that indicates if the cleanup counter should be incremented (true or false)
#   - $3 : boolean flag that indicates if the cleanup should stop after having incremented the cleanup counter (true or false)
# shellcheck disable=SC2154
cleanup() {
  set +e

  # Update exit code
  exit_code="$1"

  # Cleanup counter increment
  if [ "$2" = "${USER_CLEANUP}" ]; then
    cleanup_count=$((cleanup_count + 1))
  elif [ "$2" = "${QUEUED_USER_CLEANUP}" ]; then
    queued_signal_code="$1"
    exit_code="$1"
    cleanup_count=$((cleanup_count + 1))
    return
  fi

  if ! ${cleanup_executed}; then
    # Although concurrency is not really an issue here, it is best to avoid sending two different signals at almost the same time, so we restart the cleaning function if an exit signal has been triggered again
    if is_waiting_for_cleanup "$3"; then
      cleanup "${queued_signal_code}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
    fi

    while ! queue_exit; do true; done

    # Remove temporary JavaScript environment file to avoid conflicts with Docker
    if [ -f src/assets/environment.js ]; then
      echo "Removing temporary JavaScript file src/assets/environment.js"

      if ! rm src/assets/environment.js 2>/dev/null; then
        echo "Failed to remove the src/assets/environment.js temporary JavaScript environment file" >&2
        exit_code=8
      fi
    fi

    # Remove the temporary runner files
    if [ -f "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}" ]; then
      rm "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}" 2>/dev/null || exit_code=9
    fi

    if [ -f "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}_2" ]; then
      rm "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}_2" 2>/dev/null || exit_code=9
    fi

    # Stop the Angular process if started in background gracefully and force kill it if it cannot be stopped
    if [ -n "${NgAngular_pid}" ]; then
      if [ "${cleanup_count}" -le 1 ]; then
        kill_process "${NgAngular_pid}" "${NgAngular_stime}" 20 8 true || exit_code=$?
      else
        kill_process "${NgAngular_pid}" "${NgAngular_stime}" 20 8 false || exit_code=$?
      fi
    fi

    if is_waiting_for_cleanup "$3"; then
      cleanup "${queued_signal_code}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
    fi

    # Wait for the Angular process to exit. Allow another attempt.
    while ! wait || ! (
      code=$?
      if [ ${code} -eq 130 ] || [ ${code} -eq 143 ]; then exit 1; else exit 0; fi
    ); do
      if is_waiting_for_cleanup "$3"; then
        cleanup "${queued_signal_code}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
      fi
    done
    cleanup_executed=true
  fi

  exit "${exit_code}"
}

##################
# Core functions #
##################

# Read environment variables and configure the browser environment
configure_environment_variables() {
  # Read environment variables
  touch .env
  read_environment_file .env

  # Initialize the browser environment
  node server/FileEnvironmentConfigurator.js src/assets/environment.js @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" url "${API_URL:-http://localhost:10000}" http://localhost:10000
}

# Serve the front
# shellcheck disable=SC2154
start() {
  # Start the Angular process
  block_exit || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}" || exit $?
  ng serve --port "${FRONT_SERVER_PORT:-4200}" &
  NgAngular_pid=$!

  # Wait until the Angular process is started
  while ! queue_exit; do true; done
  wait_for_process_to_start "NgAngular" "${ng_pid}" 5 || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"

  # If required, create the temporary runner file to indicate that the Angular application is ready to be stopped
  if [ -n "${TMP_RUNNER_FILE}" ]; then
    touch "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}_2" 2>/dev/null || true
  fi

  # Continuously check if the Angular process is still alive
  while true; do
    # A pending user cleanup signal was triggered
    if is_waiting_for_cleanup; then
      cleanup "${queued_signal_code}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
    fi

    check_process_existence "${NgAngular_pid}" "${NgAngular_stime}" || cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"

    sleep 1
  done
}

##################
# Main functions #
##################

# Prevent the script from terminating in certain states and save the output signals to handle them later
block_exit() {
  set +e
  trap '' INT
  { stty_settings="$(stty -g 2>/dev/null)" && stty intr '' 2>/dev/null; } || true
}

# Queue the output signals to wait for the script to start gracefully before cleaning up
queue_exit() {
  set +e
  trap 'cleanup 130 "${QUEUED_USER_CLEANUP}"' INT
  trap 'cleanup 143 "${QUEUED_USER_CLEANUP}"' TERM
  stty "${stty_settings}" 2>/dev/null || true
}

# Allow the script to exit again
unblock_exit() {
  trap 'cleanup 130 "${USER_CLEANUP}"' INT
  trap 'cleanup 143 "${USER_CLEANUP}"' TERM
  trap 'cleanup $? "${AUTOMATED_CLEANUP}"' EXIT
  stty "${stty_settings}" 2>/dev/null || true
}

# Initialize the shell parameters
# shellcheck disable=SC2039
init_shell_params() {
  unblock_exit || exit $?
  set_process_check_existence_strategy 1 || exit $?

  set +H 2>/dev/null
  set -m 2>/dev/null
  set -e
}

# Run the front
main() {
  # Graceful cleanup flags
  cleanup_executed=false
  cleanup_count=0
  queued_signal_code=-1

  # Cleanup signals modes
  AUTOMATED_CLEANUP=1
  USER_CLEANUP=2
  QUEUED_USER_CLEANUP=3

  # Execute
  run
}

run() {
  # Initialize the shell parameters to handle the script in good conditions (exit / cleanup on error, separate process groups)
  init_shell_params

  # Read and configure environment variables
  configure_environment_variables

  # Serve the front
  start
}

main