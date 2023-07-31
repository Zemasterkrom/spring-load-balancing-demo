# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC1091
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
cd ../../../vglfront/server/no-docker || return 1
load_core_only=true . ./serve.sh

Describe 'Front server handling'
    Mock init_shell_params
        true
    End

    Mock block_exit
        true
    End

    Mock queue_exit
        true
    End

    Mock unblock_exit
        true
    End

    exit_script() {
        return "${1:-0}"
    }

    no_background_process_is_alive() {
        [ -z "$(jobs -p)" ]
    }

    no_force_kill_acted() {
        ! echo "${no_force_kill_acted}" | grep -q "force killing"
    }

    has_started() {
        ! echo "${has_started}" | grep -q "has not started"
    }

    Context 'Abstract (mocked) behavior'
        start_ng_process() {
            true
        }

        Context 'Successful start'
            check_process_existence() {
                true
            }

            kill_process() {
                if [ "$2" = "1" ]; then
                    killed_process=true
                fi
            }

            wait_for_process_to_start() {
                NgAngular_pid=1
            }

            touch() {
                if echo "$@" | grep -q "${TMP_RUNNER_FILE}_2$"; then
                    tmp_runner_file_two_created=true
                fi
            }

            is_waiting_for_cleanup() {
                if [ -z "${is_waiting_for_cleanup_executed}" ]; then
                    queued_signal_code=130
                    is_waiting_for_cleanup_executed=true
                else
                    return 1
                fi
            }

            Context 'With temporary file'
                test() {
                    true
                }

                rm() {
                    if echo "$@" | grep -q "environment\.js$"; then
                        js_environment_file_deleted=true
                    fi
                    
                    if echo "$@" | grep -q "${TMP_RUNNER_FILE}$"; then
                        tmp_runner_file_deleted=true
                    fi

                    if echo "$@" | grep -q "${TMP_RUNNER_FILE}_2$"; then
                        tmp_runner_file_two_deleted=true
                    fi
                }

                BeforeEach TMP_RUNNER_FILE=test

                It 'handles the front server successfully'
                    When call start
                    The status should eq 130
                    The stdout should satisfy true
                    The stderr should be blank
                    The variable exit_code should eq 130
                    The variable queued_signal_code should eq 130
                    The variable killed_process should eq true
                    The variable tmp_runner_file_two_created should eq true
                    The variable tmp_runner_file_two_deleted should eq true
                    The variable tmp_runner_file_deleted should eq true
                    The variable js_environment_file_deleted should eq true
                    Assert no_background_process_is_alive
                End
            End

            Context 'Without temporary file'
                test() {
                    false
                }

                It 'handles the front server successfully'
                    When call start
                    The status should eq 130
                    The stdout should satisfy true
                    The stderr should be blank
                    The variable exit_code should eq 130
                    The variable queued_signal_code should eq 130
                    The variable killed_process should eq true
                    The variable tmp_runner_file_two_created should be blank
                    The variable tmp_runner_file_two_deleted should be blank
                    The variable tmp_runner_file_deleted should be blank
                    The variable js_environment_file_deleted should be blank
                    Assert no_background_process_is_alive
                End
            End
        End

        Context 'Failed start'
            test() {
                ! echo "$@" | grep -q "${TMP_RUNNER_FILE}_2$"
            }

            wait_for_process_to_start() {
                NgAngular_pid=1
            }

            kill_process() {
                true
            }

            check_process_existence() {
                false
            }

            rm() {
                if echo "$@" | grep -q "environment\.js$"; then
                    js_environment_file_deleted=true
                fi
                    
                if echo "$@" | grep -q "${TMP_RUNNER_FILE}$"; then
                    tmp_runner_file_deleted=true
                fi

                if echo "$@" | grep -q "${TMP_RUNNER_FILE}_2$"; then
                    tmp_runner_file_two_deleted=true
                fi
            }

            It 'triggers the cleanup because the process has already exited for an unknown reason'
                When call start
                The status should eq 1
                The stdout should satisfy true
                The stderr should be blank
                The variable exit_code should eq 1
                The variable queued_signal_code should eq -1
                The variable killed_process should be blank
                The variable tmp_runner_file_two_created should be blank
                The variable tmp_runner_file_two_deleted should be blank
                The variable tmp_runner_file_deleted should eq true
                The variable js_environment_file_deleted should eq true
                Assert no_background_process_is_alive
            End
        End
    End

    Context 'Concrete run without front server start'
        is_waiting_for_cleanup() {
            if [ -z "${is_waiting_for_cleanup_executed}" ]; then
                queued_signal_code=130
                is_waiting_for_cleanup_executed=true
            else
                return 1
            fi
        }

        Context 'With temporary file'
            start_ng_process() {
                while true; do sleep 1; done &
                touch "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}"
            }

            BeforeEach TMP_RUNNER_FILE=test

            It 'handles the front server successfully'
                When call start
                The status should eq 130
                The stdout should satisfy true
                The stderr should be blank
                The variable exit_code should eq 130
                The variable queued_signal_code should eq 130
                The path "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}" should not be file
                The path "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}_2" should not be file
                The path "src/assets/environment.js" should not be exist
                The contents of file ".env" should not include "TMP_RUNNER_FILE"
                Assert no_background_process_is_alive
            End
        End

        Context 'Without temporary file'
            start_ng_process() {
                while true; do sleep 1; done &
            }

            It 'handles the front server successfully'
                When call start
                The status should eq 130
                The stdout should satisfy true
                The stderr should be blank
                The variable exit_code should eq 130
                The variable queued_signal_code should eq 130
                The path "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}" should not be file
                The path "${TMPDIR:-/tmp}/${TMP_RUNNER_FILE}_2" should not be file
                The path "src/assets/environment.js" should not be exist
                The contents of file ".env" should not include "TMP_RUNNER_FILE"
                Assert no_background_process_is_alive
            End
        End
    End
End