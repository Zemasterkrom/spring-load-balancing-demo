# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'System run (Load Balancing)'
    Mock block_exit
        true
    End

    Mock queue_exit
        true
    End

    Mock unblock_exit
        true
    End

    Mock init_shell_params
        true
    End
    
    exit_script() {
        return "${1:-0}"
    }

    auto_detect_system_stack() {
        if detect_compatible_available_java_cli >/dev/null 2>&1 && detect_compatible_available_maven_cli >/dev/null 2>&1 && detect_compatible_available_node_cli >/dev/null 2>&1; then
            environment="${SYSTEM_ENVIRONMENT}"
        else
            return 127
        fi
    }

    run() {
        # Initialize the shell parameters to handle the script in good conditions (exit / cleanup on error, separate process groups)
        init_shell_params

        # Auto-choose the launch / environment method
        auto_detect_system_stack >/dev/null

        # Read and configure environment variables
        configure_environment_variables >/dev/null

        # Build demo packages
        build >/dev/null

        # Ready : start the demo !
        start
    }

    current_location_is_at_the_base_of_the_project() {
        [ -z "$(pwd | awk '/LdFront[\/\\]?$/ { print }' 2>/dev/null)" ]
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

    BeforeEach "load_core_only=false"

    Context 'Abstract (mocked) run behavior check'
        Context 'Run mode disabled'
            exit_script() {
                return "${1:-0}"
            }

            It "checks that the demonstration isn't launched"
                When call main --no-start --no-build
                The status should be success
                The stdout should be blank
                The variable build should eq false
                The variable start should eq false
                The variable mode should eq "${LOAD_BALANCING_MODE}"
                The variable environment should eq "${SYSTEM_ENVIRONMENT}"
                Assert current_location_is_at_the_base_of_the_project
            End
        End

        Context 'Run mode enabled'
            auto_detect_system_stack() {
                environment="${SYSTEM_ENVIRONMENT}"
            }

            Mock eval_script
                true
            End

            Context 'Successfully launched background processes'
                is_waiting_for_cleanup() {
                    if [ -z "${is_waiting_for_cleanup_executed}" ]; then
                        queued_signal_code=130
                        is_waiting_for_cleanup_executed=true
                    else
                        return 1
                    fi
                }

                start_java_process() {
                    while true; do sleep 1; done &
                }

                start_npm_process() {
                    while true; do sleep 1; done &
                }
                    
                It 'checks that the run stage is triggered'
                    When call main --no-build
                    The status should eq 130
                    The line 1 of stdout should eq "Launching services ..."
                    The line 2 of stdout should eq "Waiting for LdConfig with PID ${LdConfig_pid} to start ... Please wait ..."
                    The line 3 of stdout should eq "Waiting for LdServiceOne with PID ${LdServiceOne_pid} to start ... Please wait ..."
                    The line 4 of stdout should eq "Waiting for LdServiceTwo with PID ${LdServiceTwo_pid} to start ... Please wait ..."
                    The line 5 of stdout should eq "Waiting for LdLoadbalancer with PID ${LdLoadbalancer_pid} to start ... Please wait ..."
                    The line 6 of stdout should eq "Waiting for LdDiscovery with PID ${LdDiscovery_pid} to start ... Please wait ..."
                    The line 7 of stdout should eq "Waiting for LdFront with PID ${LdFront_pid} to start ... Please wait ..."
                    The stderr should satisfy no_force_kill_acted
                    The stderr should satisfy has_started
                    The variable build should eq false
                    The variable start should eq true
                    The variable mode should eq "${LOAD_BALANCING_MODE}"
                    The variable environment should eq "${SYSTEM_ENVIRONMENT}"
                    The variable exit_code should eq 130
                    The variable queued_signal_code should eq 130
                    Assert no_background_process_is_alive
                    Assert current_location_is_at_the_base_of_the_project
                End
            End

            Context 'Exited processes'
                start_java_process() {
                    true &
                }

                start_npm_process() {
                    true &
                }

                gt_than_zero() {
                    [ "${gt_than_zero}" -gt 0 ]
                }
                    
                It 'checks that the execution step is triggered and that a cleanup is performed because the background process ends as soon as it is started'
                    When call main --no-build
                    The status should eq "${exit_code}"
                    The variable exit_code should satisfy gt_than_zero
                    The variable queued_signal_code should eq -1
                    The line 1 of stdout should eq "Launching services ..."
                    The line 2 of stdout should eq "Waiting for LdConfig with PID ${LdConfig_pid} to start ... Please wait ..."
                    The line 3 of stdout should eq "Waiting for LdServiceOne with PID ${LdServiceOne_pid} to start ... Please wait ..."
                    The line 4 of stdout should eq "Waiting for LdServiceTwo with PID ${LdServiceTwo_pid} to start ... Please wait ..."
                    The line 5 of stdout should eq "Waiting for LdLoadbalancer with PID ${LdLoadbalancer_pid} to start ... Please wait ..."
                    The line 6 of stdout should eq "Waiting for LdDiscovery with PID ${LdDiscovery_pid} to start ... Please wait ..."
                    The line 7 of stdout should eq "Waiting for LdFront with PID ${LdFront_pid} to start ... Please wait ..."
                    The stderr should satisfy no_force_kill_acted
                    The variable build should eq false
                    The variable start should eq true
                    The variable mode should eq "${LOAD_BALANCING_MODE}"
                    The variable environment should eq "${SYSTEM_ENVIRONMENT}"
                    Assert no_background_process_is_alive
                    Assert current_location_is_at_the_base_of_the_project
                End
            End
        End
    End

    Context 'Concrete run behavior check'
        is_waiting_for_cleanup() {
            if [ -z "${is_waiting_for_cleanup_executed}" ]; then
                queued_signal_code=130
                is_waiting_for_cleanup_executed=true
            else
                return 1
            fi
        }

        It 'starts the demonstration without Docker and stops it successfully'
            When call main
            The status should eq 130
            The line 1 of stdout should eq "Launching services ..."
            The stderr should satisfy no_force_kill_acted
            The stderr should satisfy has_started
            The variable build should eq true
            The variable start should eq true
            The variable mode should eq "${LOAD_BALANCING_MODE}"
            The variable environment should eq "${SYSTEM_ENVIRONMENT}"
            The variable exit_code should eq 130
            The variable queued_signal_code should eq 130
            The variable LdServiceTwo_pid should be present
            The variable LdLoadbalancer_pid should be present
            The variable LdDiscovery_pid should be present
            The contents of file "ldfront/.env" should not include "TMP_RUNNER_FILE"
            The path "ldfront/src/assets/environment.js" should not be exist
            Assert no_background_process_is_alive
            Assert current_location_is_at_the_base_of_the_project
        End
    End
End