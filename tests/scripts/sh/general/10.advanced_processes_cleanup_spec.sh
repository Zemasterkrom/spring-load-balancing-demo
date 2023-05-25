# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Cleanup logic check'
    wait_until_tmp_runner_file_exists() {
        echo "Waited for the creation of the temporary file : $*"
    }
        
    kill_process() {
        if [ "$5" = "true" ]; then
            echo "Stopped : $*"
        else
            echo "Force killed : $*"
        fi
    }

    eval_script() {
        echo "Eval : $*"
    }

    exit_script() {
        return "${1:-0}"
    }

    Context 'Basic cleanup only without any registered process'
        It 'successfully stops the script without taking any advanced action'
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 0
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The variable cleanup_count should eq 0
        End
    End

    Context 'Basic cleanup only'
        check_process_existence() {
            if [ -z "${check_process_existence_exec_count}" ]; then
                check_process_existence_exec_count=0
            fi

            check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

            if [ "${check_process_existence_exec_count}" -le 2 ]; then
                echo "Checked process existence : $*"
            else
                return 1
            fi
        }

        Before "register_process_info Test 1"

        It 'successfully verifies the existence of the process and stops it'
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 0
            The status should be success
            The lines of stdout should equal 5
            The stderr should be blank
            The variable cleanup_count should eq 0
            The line 1 of stdout should eq "Checked process existence :  1"
            The line 2 of stdout should eq "Checked process existence :  1"
            The line 3 of stdout should eq "Stopped : Test 1 20 8 true"
            The line 4 of stdout should eq "Waiting for processes to shut down ..."
            The line 5 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
        End
    End

    Context 'Basic cleanup only (force kill)'
        check_process_existence() {
            if [ -z "${check_process_existence_exec_count}" ]; then
                check_process_existence_exec_count=0
            fi

            check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

            if [ "${check_process_existence_exec_count}" -le 2 ]; then
                echo "Checked process existence : $*"
            else
                return 1
            fi
        }

        Before "cleanup_count=2 && register_process_info Test 1"

        It 'successfully verifies the existence of the process and kills it'
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 2
            The status should be success
            The lines of stdout should equal 5
            The stderr should be blank
            The variable cleanup_count should eq 2
            The line 1 of stdout should eq "Checked process existence :  1"
            The line 2 of stdout should eq "Checked process existence :  1"
            The line 3 of stdout should eq "Force killed : Test 1 20 8 false"
            The line 4 of stdout should eq "Waiting for processes to shut down ..."
            The line 5 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
        End
    End

    Context 'Advanced cleanup only'
        check_process_existence() {
            if [ -z "${check_process_existence_exec_count}" ]; then
                check_process_existence_exec_count=0
            fi

            check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

            if [ "${check_process_existence_exec_count}" -le 1 ]; then
                echo "Checked process existence : $*"
            else
                return 1
            fi
        }

        Before 'register_process_info Test "" true'

        It 'skips the process check, then executes a custom stop command'
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 0
            The status should be success
            The lines of stdout should equal 4
            The stderr should be blank
            The variable cleanup_count should eq 0
            The line 1 of stdout should eq "Checked process existence :  "
            The line 2 of stdout should eq "Eval : true"
            The line 3 of stdout should eq "Waiting for processes to shut down ..."
            The line 4 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
        End
    End

    Context 'Advanced cleanup only (force kill)'
        check_process_existence() {
            if [ -z "${check_process_existence_exec_count}" ]; then
                check_process_existence_exec_count=0
            fi

            check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

            if [ "${check_process_existence_exec_count}" -le 1 ]; then
                echo "Checked process existence : $*"
            else
                return 1
            fi
        }

        Before 'cleanup_count=2 && register_process_info Test "" stop_command kill_command'

        It 'skips the process check, then executes a custom kill command'
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 2
            The status should be success
            The lines of stdout should equal 4
            The stderr should be blank
            The variable cleanup_count should eq 2
            The line 1 of stdout should eq "Checked process existence :  "
            The line 2 of stdout should eq "Eval : kill_command"
            The line 3 of stdout should eq "Waiting for processes to shut down ..."
            The line 4 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
        End
    End

    Context 'Basic cleanup with advanced cleanup'
        check_process_existence() {
            if [ -z "${check_process_existence_exec_count}" ]; then
                check_process_existence_exec_count=0
            fi

            check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

            if [ "${check_process_existence_exec_count}" -le 2 ]; then
                echo "Checked process existence : $*"
            else
                return 1
            fi
        }

        Before 'register_process_info Test 1 true'

        It 'successfully verifies the existence of the process and stops it, then executes a custom stop command'
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 0
            The status should be success
            The lines of stdout should equal 6
            The stderr should be blank
            The variable cleanup_count should eq 0
            The line 1 of stdout should eq "Checked process existence :  1"
            The line 2 of stdout should eq "Checked process existence :  1"
            The line 3 of stdout should eq "Stopped : Test 1 20 8 true"
            The line 4 of stdout should eq "Eval : true"
            The line 5 of stdout should eq "Waiting for processes to shut down ..."
            The line 6 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
        End
    End

    Context 'Basic cleanup with advanced cleanup (force kill)'
        check_process_existence() {
            if [ -z "${check_process_existence_exec_count}" ]; then
                check_process_existence_exec_count=0
            fi

            check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

            if [ "${check_process_existence_exec_count}" -le 2 ]; then
                echo "Checked process existence : $*"
            else
                return 1
            fi
        }

        Before 'cleanup_count=2 && register_process_info Test 1 stop_command kill_command'

        It "successfully verifies the existence of the process and kills it, then executes a custom kill command"
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 2
            The status should be success
            The lines of stdout should equal 6
            The stderr should be blank
            The variable cleanup_count should eq 2
            The line 1 of stdout should eq "Checked process existence :  1"
            The line 2 of stdout should eq "Checked process existence :  1"
            The line 3 of stdout should eq "Force killed : Test 1 20 8 false"
            The line 4 of stdout should eq "Eval : kill_command"
            The line 5 of stdout should eq "Waiting for processes to shut down ..."
            The line 6 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
        End
    End

    Context 'Basic cleanup with advanced cleanup and a custom check command (force kill)'
        check_process_existence() {
            if [ -z "${check_process_existence_exec_count}" ]; then
                check_process_existence_exec_count=0
            fi

            check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

            if [ "${check_process_existence_exec_count}" -le 2 ]; then
                echo "Checked process existence : $*"
            else
                return 1
            fi
        }

        Before 'cleanup_count=2 && register_process_info Test 1 stop_command kill_command check_command'

        It 'successfully verifies the existence of the process (in combination with a custom check command) and kills it, then executes a custom kill command'
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 2
            The status should be success
            The lines of stdout should equal 6
            The stderr should be blank
            The variable cleanup_count should eq 2
            The line 1 of stdout should eq "Checked process existence : check_command 1"
            The line 2 of stdout should eq "Checked process existence :  1"
            The line 3 of stdout should eq "Force killed : Test 1 20 8 false"
            The line 4 of stdout should eq "Eval : kill_command"
            The line 5 of stdout should eq "Waiting for processes to shut down ..."
            The line 6 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
        End
    End

    Context 'Basic cleanup with advanced cleanup (two cleanup tries)'
        check_process_existence() {
            if [ -z "${check_process_existence_exec_count}" ]; then
                check_process_existence_exec_count=0
            fi

            check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

            if [ "${check_process_existence_exec_count}" -le 3 ]; then
                echo "Checked process existence : $*"
            else
                return 1
            fi
        }

        is_waiting_for_cleanup() {
            if [ -z "${is_waiting_for_cleanup_exec_count}" ]; then
                is_waiting_for_cleanup_exec_count=0
            fi

            is_waiting_for_cleanup_exec_count=$((is_waiting_for_cleanup_exec_count + 1))

            if [ "${is_waiting_for_cleanup_exec_count}" -eq 3 ]; then
                queued_signal_code=130
                exit_code=130
                enabled_sigint_code=true
                cleanup_count=$((cleanup_count + 1))
                check_process_existence_exec_count=1

                echo "Waiting for cleanup"
            else
                return 1
            fi
        }

        Before 'cleanup_count=1 && register_process_info Test 1 stop_command kill_command check_command'

        It "tries to process the cleanup two times since some processes aren't killed"
            When call cleanup 0 "${AUTOMATED_CLEANUP}" 1
            The status should eq 130
            The lines of stdout should equal 14
            The stderr should be blank
            The variable cleanup_count should eq 2
            The line 1 of stdout should eq "Checked process existence : check_command 1"
            The line 2 of stdout should eq "Checked process existence :  1"
            The line 3 of stdout should eq "Stopped : Test 1 20 8 true"
            The line 4 of stdout should eq "Eval : stop_command"
            The line 5 of stdout should eq "Waiting for processes to shut down ..."
            The line 6 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
            The line 7 of stdout should eq "Checked process existence : check_command 1"
            The line 8 of stdout should eq "Waiting for cleanup"
            The line 9 of stdout should eq "Checked process existence : check_command 1"
            The line 10 of stdout should eq "Checked process existence :  1"
            The line 11 of stdout should eq "Force killed : Test 1 20 8 false"
            The line 12 of stdout should eq "Eval : kill_command"
            The line 13 of stdout should eq "Waiting for processes to shut down ..."
            The line 14 of stdout should eq "If the processes do not terminate within 20 seconds, press CTRL-C again to try to force the processes to shut down"
        End
    End
End