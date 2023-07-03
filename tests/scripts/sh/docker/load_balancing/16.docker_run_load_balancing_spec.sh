# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Docker run (Load Balancing)'
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
        if detect_compatible_available_docker_compose_cli >/dev/null 2>&1; then
            environment="${DOCKER_ENVIRONMENT}"
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
        [ -z "$(pwd | awk '/vglfront[\/\\]?$/ { print }' 2>/dev/null)" ]
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

    BeforeEach "source_only=false"

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
                The variable environment should eq "${DOCKER_ENVIRONMENT}"
                Assert current_location_is_at_the_base_of_the_project
            End
        End

        Context 'Run mode enabled'
            auto_detect_system_stack() {
                environment="${DOCKER_ENVIRONMENT}"
                docker_compose_cli="docker compose"
            }

            Mock eval_script
                true
            End
            
            Context 'Successfully launched Docker services'
                start_docker_compose_services() {
                    if echo "$@" | grep -q no-load-balancing; then
                        start_error=1
                    fi

                    if [ "${start_error}" -ne 0 ]; then
                        cleanup "${start_error}" "${AUTOMATED_CLEANUP}" "${cleanup_count}"
                        return "${exit_code}"
                    fi

                    cleanup 130 "${AUTOMATED_CLEANUP}" "${cleanup_count}"
                    return "${exit_code}"
                }
                    
                It 'checks that the run stage is triggered'
                    When call main --no-build
                    The status should eq 130
                    The stdout should eq "Launching Docker services ..."
                    The stderr should satisfy no_force_kill_acted
                    The stderr should satisfy has_started
                    The variable build should eq false
                    The variable start should eq true
                    The variable mode should eq "${LOAD_BALANCING_MODE}"
                    The variable environment should eq "${DOCKER_ENVIRONMENT}"
                    The variable exit_code should eq 130
                    Assert no_background_process_is_alive
                    Assert current_location_is_at_the_base_of_the_project
                End
            End

            Context 'Docker services start error'
                check_docker_services_stop_operation_status() {
                    if echo "$@" | grep -q "stop"; then
                        started_stopping_docker_services=true
                    fi

                    if echo "$@" | grep -q "kill"; then
                        started_killing_docker_services=true
                    fi

                }

                docker() {
                    check_docker_services_stop_operation_status "$@"
                    false
                }
                    
                It 'stops services because a Docker error occurred when starting Docker services'
                    When call main --no-build
                    The status should eq 1
                    The stdout should eq "Launching Docker services ..."
                    The stderr should satisfy no_force_kill_acted
                    The stderr should satisfy has_started
                    The variable build should eq false
                    The variable start should eq true
                    The variable mode should eq "${LOAD_BALANCING_MODE}"
                    The variable environment should eq "${DOCKER_ENVIRONMENT}"
                    The variable exit_code should eq 1
                    The variable started_stopping_docker_services should eq true
                    The variable started_killing_docker_services should eq true
                    Assert no_background_process_is_alive
                    Assert current_location_is_at_the_base_of_the_project
                End
            End

            Context 'Docker services stop error'
                check_docker_services_stop_operation_status() {
                    if echo "$@" | grep -q "stop"; then
                        started_stopping_docker_services=true
                    fi

                    if echo "$@" | grep -q "kill"; then
                        started_killing_docker_services=true
                    fi
                }

                docker() {
                    check_docker_services_stop_operation_status "$@"

                    if echo "$@" | grep -q "stop\|kill"; then
                        false
                    fi
                }
                    
                It 'kills services because a Docker error occurred when stopping Docker services'
                    When call main --no-build
                    The status should eq 1
                    The stdout should eq "Launching Docker services ..."
                    The stderr should satisfy no_force_kill_acted
                    The stderr should satisfy has_started
                    The variable build should eq false
                    The variable start should eq true
                    The variable mode should eq "${LOAD_BALANCING_MODE}"
                    The variable environment should eq "${DOCKER_ENVIRONMENT}"
                    The variable exit_code should eq 1
                    The variable started_stopping_docker_services should eq true
                    The variable started_killing_docker_services should eq true
                    Assert no_background_process_is_alive
                    Assert current_location_is_at_the_base_of_the_project
                End
            End
        End
    End

    Context 'Concrete run behavior check'
        start_docker_compose_services() {
            if [ -n "${project_name}" ]; then
                project_argument="-p ${project_name}"
            fi

            ${docker_compose_cli} "$@" -d || {
                start_error=$?
                ${docker_compose_cli} ${project_argument} stop -t 20 || ${docker_compose_cli} ${project_argument} kill
                cleanup ${start_error} "${AUTOMATED_CLEANUP}" "${cleanup_count}"

                return "${exit_code}"
            }

            ${docker_compose_cli} ${project_argument} stop -t 20 || ${docker_compose_cli} ${project_argument} kill || {
                cleanup $? "${AUTOMATED_CLEANUP}" "${cleanup_count}"
                return "${exit_code}"
            }
            cleanup 130 "${AUTOMATED_CLEANUP}" "${cleanup_count}"
        }

        load_balancing_containers_are_stopped() {
            running_services_counter=0
            running_services=

            while IFS= read -r SERVICE_NAME; do
                if [ -n "${SERVICE_NAME}" ]; then
                    running_services_counter=$((running_services_counter + 1))
                fi
            done <<EOF
$(${docker_compose_cli} -p vglloadbalancing-enabled ps --filter "status=running" --services)
$(${docker_compose_cli} -p vglloadbalancing-enabled ps --filter "status=restarting" --services)
EOF

            [ "${running_services_counter}" -eq 0 ]
        }

        It 'starts the demonstration with Docker and stops it successfully'
            When call main --no-build
            The status should eq 130
            The line 1 of stdout should eq "Launching Docker services ..."
            The stderr should satisfy no_force_kill_acted
            The stderr should satisfy has_started
            The variable build should eq false
            The variable start should eq true
            The variable mode should eq "${LOAD_BALANCING_MODE}"
            The variable environment should eq "${DOCKER_ENVIRONMENT}"
            The variable docker_compose_cli should be present
            The variable exit_code should eq 130
            Assert no_background_process_is_alive
            Assert current_location_is_at_the_base_of_the_project
            Assert load_balancing_containers_are_stopped
        End
    End
End