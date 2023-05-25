# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Traps handling'
    write_subshell_variables_to_file() {
        echo "cleanup_count=${cleanup_count}
queued_signal_code=${queued_signal_code}
exit_code=${exit_code}
enabled_sigterm_code=${enabled_sigterm_code}
enabled_sigint_code=${enabled_sigint_code}
cleanup_executed=${cleanup_executed}" > "${TMP_DATA_FILE_LOCATION}_subshell_data_${exec_count}"
    }

    exit_script() {
        write_subshell_variables_to_file
    }

    return_script() {
        exit_script
    } 

    custom_subshell_call() {
        true
    }

    run_subshell_initializer() {
        exec_count="$(cat "${TMP_DATA_FILE_LOCATION}")"

        if [ -z "${exec_count}" ]; then
            exec_count=0
        fi

        exec_count=$((exec_count + 1))
        echo "${exec_count}" > "${TMP_DATA_FILE_LOCATION}"
        
        ( 
            { custom_subshell_call && while true; do sleep 1; done } >/dev/null & 
            echo $! > "${TMP_DATA_FILE_LOCATION}_subshell"
        )
        subshell_process_PID="$(cat "${TMP_DATA_FILE_LOCATION}_subshell")"
        subshell_initializer_timeout=0

        while ! ps -p "${subshell_process_PID}" >/dev/null; do
            sleep 1
            subshell_initializer_timeout=$((subshell_initializer_timeout + 1))

            if [ ${subshell_initializer_timeout} -ge 5 ]; then
                return 1
            fi
        done

        rm "${TMP_DATA_FILE_LOCATION}_subshell"
    }

    dump_load_subshell_variables() {
        while [ ! -f "${TMP_DATA_FILE_LOCATION}_subshell_data_${exec_count}" ]; do
            sleep 1
            dump_load_subshell_variables_timeout=$((send_kill_signal_timeout + 1))

            if [ ${dump_load_subshell_variables_timeout} -ge 5 ]; then
                rm "${TMP_DATA_FILE_LOCATION}_subshell_data_${exec_count}" 2>/dev/null || true
                return 1
            fi
        done

        . "${TMP_DATA_FILE_LOCATION}_subshell_data_${exec_count}" && rm "${TMP_DATA_FILE_LOCATION}_subshell_data_${exec_count}"
    }

    send_kill_signal() {
        kill "$1" "${subshell_process_PID}"
        send_kill_signal_timeout=0

        if [ -z "$2" ] || [ "$2" = "true" ]; then
            dump_load_subshell_variables
        fi
    }

    process_is_still_alive() {
        ps -p "${subshell_process_PID}" >/dev/null
    }

    kill_subshell_initializer() {
        kill -9 "${subshell_process_PID}" 2>/dev/null || true
    }
    
    BeforeEach run_subshell_initializer
    AfterEach kill_subshell_initializer

    Context 'Stop signal blocked'
        custom_subshell_call() {
            block_exit
        }

        It 'ignores the TERM / INT signal since they are blocked'
            When call send_kill_signal -15 false
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 0
            The variable queued_signal_code should eq -1
            The variable exit_code should eq 0
            The variable enabled_sigterm_code should eq false
            The variable enabled_sigint_code should eq false
            The variable cleanup_executed should eq false
            The result of function process_is_still_alive should be successful
        End
    End

    Context 'Queue signal'
        custom_subshell_call() {
            queue_exit
        }

        It 'queues the TERM signal'
            When call send_kill_signal -15
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 1
            The variable queued_signal_code should eq 143
            The variable exit_code should eq 143
            The variable enabled_sigterm_code should eq true
            The variable enabled_sigint_code should eq false
            The variable cleanup_executed should eq false
            The result of function process_is_still_alive should be successful
        End

        It 'queues the TERM signal twice'
            When call send_kill_signal -15 && send_kill_signal -15
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 2
            The variable queued_signal_code should eq 143
            The variable exit_code should eq 143
            The variable enabled_sigterm_code should eq true
            The variable enabled_sigint_code should eq false
            The variable cleanup_executed should eq false
            The result of function process_is_still_alive should be successful
        End

        It 'queues the INT signal'
            When call send_kill_signal -2
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 1
            The variable queued_signal_code should eq 130
            The variable exit_code should eq 130
            The variable enabled_sigterm_code should eq false
            The variable enabled_sigint_code should eq true
            The variable cleanup_executed should eq false
            The result of function process_is_still_alive should be successful
        End

        It 'queues the INT signal twice'
            When call send_kill_signal -2 && send_kill_signal -2
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 2
            The variable queued_signal_code should eq 130
            The variable exit_code should eq 130
            The variable enabled_sigterm_code should eq false
            The variable enabled_sigint_code should eq true
            The variable cleanup_executed should eq false
            The result of function process_is_still_alive should be successful
        End

        It 'queues the TERM signal and an INT signal'
            When call send_kill_signal -15 && send_kill_signal -2
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 2
            The variable queued_signal_code should eq 130
            The variable exit_code should eq 130
            The variable enabled_sigterm_code should eq true
            The variable enabled_sigint_code should eq true
            The variable cleanup_executed should eq false
            The result of function process_is_still_alive should be successful
        End

        It 'queues the INT signal twice and an TERM signal twice'
            When call send_kill_signal -2 && send_kill_signal -2 && send_kill_signal -15 && send_kill_signal -15
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 4
            The variable queued_signal_code should eq 143
            The variable exit_code should eq 143
            The variable enabled_sigterm_code should eq true
            The variable enabled_sigint_code should eq true
            The variable cleanup_executed should eq false
            The result of function process_is_still_alive should be successful
        End

        It 'queues the TERM signal twice and an INT signal twice'
            When call send_kill_signal -15 && send_kill_signal -15 && send_kill_signal -2 && send_kill_signal -2
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 4
            The variable queued_signal_code should eq 130
            The variable exit_code should eq 130
            The variable enabled_sigterm_code should eq true
            The variable enabled_sigint_code should eq true
            The variable cleanup_executed should eq false
            The result of function process_is_still_alive should be successful
        End
    End

    Context 'Exit signal'
        custom_subshell_call() {
            unblock_exit && exit
        }

        It 'flags the cleanup as completed'
            When call dump_load_subshell_variables
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 0
            The variable queued_signal_code should eq -1
            The variable exit_code should eq 0
            The variable enabled_sigterm_code should eq false
            The variable enabled_sigint_code should eq false
            The variable cleanup_executed should eq true
            The result of function process_is_still_alive should not be successful
        End
    End

    Context 'Exit signals'
        custom_subshell_call() {
            unblock_exit
        }

        exit_script() {
            write_subshell_variables_to_file
            exit "${1:-0}"
        }

        It 'increments the cleanup counter and flags the cleanup as completed (TERM)'
            When call send_kill_signal -15
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 1
            The variable queued_signal_code should eq -1
            The variable exit_code should eq 143
            The variable enabled_sigterm_code should eq false
            The variable enabled_sigint_code should eq false
            The variable cleanup_executed should eq true
            The result of function process_is_still_alive should not be successful
        End

        It 'increments the cleanup counter and flags the cleanup as completed (INT)'
            When call send_kill_signal -2
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 1
            The variable queued_signal_code should eq -1
            The variable exit_code should eq 130
            The variable enabled_sigterm_code should eq false
            The variable enabled_sigint_code should eq false
            The variable cleanup_executed should eq true
            The result of function process_is_still_alive should not be successful
        End

        Context 'Doubled exit signals'
            exit_script() {
                unblock_exit
                write_subshell_variables_to_file

                if [ -z "${exit_count}" ]; then
                    exit_count=0
                fi

                exit_count=$((exit_count + 1))

                if [ "${exit_count}" -eq 2 ]; then
                    exit "${1:-0}"
                fi
            }

            It 'increments the cleanup counter twice and flags the cleanup as completed (INT)'
                When call send_kill_signal -2 && send_kill_signal -2
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq -1
                The variable exit_code should eq 130
                The variable enabled_sigterm_code should eq false
                The variable enabled_sigint_code should eq false
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End

            It 'increments the cleanup counter twice and flags the cleanup as completed (TERM)'
                When call send_kill_signal -15 && send_kill_signal -15
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq -1
                The variable exit_code should eq 143
                The variable enabled_sigterm_code should eq false
                The variable enabled_sigint_code should eq false
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End

            It 'increments the cleanup counter twice and flags the cleanup as completed (TERM + INT)'
                When call send_kill_signal -15 && send_kill_signal -2
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq -1
                The variable exit_code should eq 130
                The variable enabled_sigterm_code should eq false
                The variable enabled_sigint_code should eq false
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End

            It 'increments the cleanup counter twice and flags the cleanup as completed (INT + TERM)'
                When call send_kill_signal -2 && send_kill_signal -15
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq -1
                The variable exit_code should eq 143
                The variable enabled_sigterm_code should eq false
                The variable enabled_sigint_code should eq false
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End
        End

        Context 'Doubled signals (unblock_exit + queue_exit)'
            exit_script() {
                queue_exit
                write_subshell_variables_to_file

                if [ -z "${exit_count}" ]; then
                    exit_count=0
                fi

                exit_count=$((exit_count + 1))

                if [ "${exit_count}" -eq 2 ]; then
                    exit "${1:-0}"
                fi
            }

            It 'increments the cleanup counter twice and flags the cleanup as completed (INT)'
                When call send_kill_signal -2 && send_kill_signal -2
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq 130
                The variable exit_code should eq 130
                The variable enabled_sigterm_code should eq false
                The variable enabled_sigint_code should eq true
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End

            It 'increments the cleanup counter twice and flags the cleanup as completed (TERM)'
                When call send_kill_signal -15 && send_kill_signal -15
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq 143
                The variable exit_code should eq 143
                The variable enabled_sigterm_code should eq true
                The variable enabled_sigint_code should eq false
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End

            It 'increments the cleanup counter twice and flags the cleanup as completed (TERM + INT)'
                When call send_kill_signal -15 && send_kill_signal -2
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq 130
                The variable exit_code should eq 130
                The variable enabled_sigterm_code should eq false
                The variable enabled_sigint_code should eq true
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End

            It 'increments the cleanup counter twice and flags the cleanup as completed (INT + TERM)'
                When call send_kill_signal -2 && send_kill_signal -15
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq 143
                The variable exit_code should eq 143
                The variable enabled_sigterm_code should eq true
                The variable enabled_sigint_code should eq false
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End
        End
    End

    Context 'Cleanup queue management'
        custom_subshell_call() {
            unblock_exit
        }

        exit_script() {
            write_subshell_variables_to_file
            exit "${1:-0}"
        }

        Describe 'Handling a queued TERM signal'
            is_waiting_for_cleanup() {
                if [ -z "${is_waiting_for_cleanup_exec_count}" ]; then
                    is_waiting_for_cleanup_exec_count=0
                fi

                if [ "${is_waiting_for_cleanup_exec_count}" -lt 1 ]; then
                    is_waiting_for_cleanup_exec_count=$((is_waiting_for_cleanup_exec_count + 1))
                    cleanup_count=$((cleanup_count + 1))
                    queued_signal_code=143
                    enabled_sigterm_code=true

                    return
                else
                    return 1
                fi
            }

            It 'executes the cleanup again since a signal has been queued'
                When call send_kill_signal -15
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq 143
                The variable exit_code should eq 143
                The variable enabled_sigterm_code should eq true
                The variable enabled_sigint_code should eq false
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End
        End

        Context 'Handling a queued TERM signal when the current handled signal is INT'
            is_waiting_for_cleanup() {
                if [ -z "${is_waiting_for_cleanup_exec_count}" ]; then
                    is_waiting_for_cleanup_exec_count=0
                fi

                if [ "${is_waiting_for_cleanup_exec_count}" -lt 1 ]; then
                    is_waiting_for_cleanup_exec_count=$((is_waiting_for_cleanup_exec_count + 1))
                    cleanup_count=$((cleanup_count + 1))
                    queued_signal_code=143
                    enabled_sigterm_code=true

                    return
                else
                    return 1
                fi
            }

            It 'executes the cleanup again since a signal has been queued'
                When call send_kill_signal -2
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq 143
                The variable exit_code should eq 143
                The variable enabled_sigterm_code should eq true
                The variable enabled_sigint_code should eq false
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End
        End

        Context 'Handling a queued INT signal'
            is_waiting_for_cleanup() {
                if [ -z "${is_waiting_for_cleanup_exec_count}" ]; then
                    is_waiting_for_cleanup_exec_count=0
                fi

                if [ "${is_waiting_for_cleanup_exec_count}" -lt 1 ]; then
                    is_waiting_for_cleanup_exec_count=$((is_waiting_for_cleanup_exec_count + 1))
                    cleanup_count=$((cleanup_count + 1))
                    queued_signal_code=130
                    enabled_sigint_code=true

                    return
                else
                    return 1
                fi
            }

            It 'executes the cleanup again since a signal has been queued'
                When call send_kill_signal -2
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq 130
                The variable exit_code should eq 130
                The variable enabled_sigterm_code should eq false
                The variable enabled_sigint_code should eq true
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End
        End

        Context 'Handling a queued INT signal when the current handled signal is TERM'
            is_waiting_for_cleanup() {
                if [ -z "${is_waiting_for_cleanup_exec_count}" ]; then
                    is_waiting_for_cleanup_exec_count=0
                fi

                if [ "${is_waiting_for_cleanup_exec_count}" -lt 1 ]; then
                    is_waiting_for_cleanup_exec_count=$((is_waiting_for_cleanup_exec_count + 1))
                    cleanup_count=$((cleanup_count + 1))
                    queued_signal_code=130
                    enabled_sigint_code=true

                    return
                else
                    return 1
                fi
            }

            It 'executes the cleanup again since a signal has been queued'
                When call send_kill_signal -2
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable cleanup_count should eq 2
                The variable queued_signal_code should eq 130
                The variable exit_code should eq 130
                The variable enabled_sigterm_code should eq false
                The variable enabled_sigint_code should eq true
                The variable cleanup_executed should eq true
                The result of function process_is_still_alive should not be successful
            End
        End
    End
End