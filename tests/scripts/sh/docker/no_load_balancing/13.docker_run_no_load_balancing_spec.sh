# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Docker run (no Load Balancing)'
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

    Describe 'Abstract (mocked) run behavior check'
        Describe 'Run mode disabled'
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

        Describe 'Run mode enabled'
            auto_detect_system_stack() {
                environment="${DOCKER_ENVIRONMENT}"
                docker_compose_cli="docker compose"
            }

            Mock eval_script
                true
            End

            docker_process_is_runned_without_load_balancing_mode() {
                if [ -z "${docker_process_is_runned_without_load_balancing_mode_timeout}" ]; then
                    docker_process_is_runned_without_load_balancing_mode_timeout=0
                fi

                while [ ! -f "${TMP_DATA_FILE_LOCATION}_docker_run_test_no_load_balancing" ]; do
                    docker_process_is_runned_without_load_balancing_mode_timeout=$((docker_process_is_runned_without_load_balancing_mode_timeout + 1))

                    if [ "${docker_process_is_runned_without_load_balancing_mode_timeout}" -ge 5 ]; then
                        return 1
                    fi
                done

                [ "$(cat "${TMP_DATA_FILE_LOCATION}_docker_run_test_no_load_balancing")" = "Docker run (no load-balancing) triggered" ] && rm "${TMP_DATA_FILE_LOCATION}_docker_run_test_no_load_balancing"
            }

            Describe 'Successfully launched Docker services'
                is_waiting_for_cleanup() {
                    if [ -z "${is_waiting_for_cleanup_executed}" ]; then
                        queued_signal_code=130
                        is_waiting_for_cleanup_executed=true
                    else
                        return 1
                    fi
                }

                start_docker_compose_services() {
                    { if echo "$@" | grep -q docker-compose-no-load-balancing.yml && echo "$@" | grep -q up ; then
                        echo "Docker run (no load-balancing) triggered" > "${TMP_DATA_FILE_LOCATION}_docker_run_test_no_load_balancing"
                        touch "${TMPDIR:-/tmp}/${DockerComposeOrchestrator_tmp_runner_file}"

                        while true; do
                            sleep 1
                        done
                    fi; } &
                }
                    
                It 'checks that the run stage is triggered'
                    When call main --no-build --no-load-balancing
                    The status should eq 130
                    The line 1 of stdout should eq "Launching Docker services ..."
                    The line 2 of stdout should eq "Waiting for DockerComposeOrchestrator with PID ${DockerComposeOrchestrator_pid} to start ... Please wait ..."
                    The stderr should satisfy no_force_kill_acted
                    The stderr should satisfy has_started
                    The variable build should eq false
                    The variable start should eq true
                    The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
                    The variable environment should eq "${DOCKER_ENVIRONMENT}"
                    The variable exit_code should eq 130
                    The variable queued_signal_code should eq 130
                    Assert docker_process_is_runned_without_load_balancing_mode
                    Assert no_background_process_is_alive
                    Assert current_location_is_at_the_base_of_the_project
                End
            End

            Describe 'Exited Docker services'
                start_docker_compose_services() {
                    { if echo "$@" | grep -q docker-compose-no-load-balancing.yml && echo "$@" | grep -q up ; then
                        echo "Docker run (no load-balancing) triggered" > "${TMP_DATA_FILE_LOCATION}_docker_run_test_no_load_balancing"
                        touch "${TMPDIR:-/tmp}/${DockerComposeOrchestrator_tmp_runner_file}"
                    fi; } &
                }
                    
                docker_process_is_runned_without_load_balancing_mode() {
                    if [ -z "${docker_process_is_runned_without_load_balancing_mode_timeout}" ]; then
                        docker_process_is_runned_without_load_balancing_mode_timeout=0
                    fi

                    while [ ! -f "${TMP_DATA_FILE_LOCATION}_docker_run_test_no_load_balancing" ]; do
                        docker_process_is_runned_without_load_balancing_mode_timeout=$((docker_process_is_runned_without_load_balancing_mode_timeout + 1))

                        if [ "${docker_process_is_runned_without_load_balancing_mode_timeout}" -ge 5 ]; then
                            return 1
                        fi
                    done

                    [ "$(cat "${TMP_DATA_FILE_LOCATION}_docker_run_test_no_load_balancing")" = "Docker run (no load-balancing) triggered" ] && rm "${TMP_DATA_FILE_LOCATION}_docker_run_test_no_load_balancing"
                }

                gt_than_zero() {
                    [ "${gt_than_zero}" -gt 0 ]
                }
                    
                It 'checks that the execution step is triggered and that a cleanup is performed because the background process ends as soon as it is started'
                    When call main --no-build --no-load-balancing
                    The status should eq "${exit_code}"
                    The variable exit_code should satisfy gt_than_zero
                    The variable queued_signal_code should eq -1
                    The line 1 of stdout should eq "Launching Docker services ..."
                    The line 2 of stdout should eq "Waiting for DockerComposeOrchestrator with PID ${DockerComposeOrchestrator_pid} to start ... Please wait ..."
                    The stderr should satisfy no_force_kill_acted
                    The variable build should eq false
                    The variable start should eq true
                    The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
                    The variable environment should eq "${DOCKER_ENVIRONMENT}"
                    Assert docker_process_is_runned_without_load_balancing_mode
                    Assert no_background_process_is_alive
                    Assert current_location_is_at_the_base_of_the_project
                End
            End
        End
    End

    Describe 'Concrete run behavior check'        
        is_waiting_for_cleanup() {
            if [ -z "${wait_for_docker_services_start_counter}" ]; then
                wait_for_docker_services_start_counter=0
                is_waiting_for_cleanup_executed=false
            fi

            if ! ${is_waiting_for_cleanup_executed}; then 
                wait_for_docker_services_start_counter=$((wait_for_docker_services_start_counter + 1))
                running_services_counter=0
                running_services=

                while IFS= read -r SERVICE_NAME; do
                    if [ -n "${SERVICE_NAME}" ] && ! echo "${running_services}" | grep -q "\b${SERVICE_NAME}\b"; then
                        case "${SERVICE_NAME}" in
                            vgldatabase|vglconfig|vglfront|vglservice)
                                running_services_counter=$((running_services_counter + 1))
                                running_services="${running_services} ${SERVICE_NAME}";;
                        esac
                    fi
                done <<EOF
$(${docker_compose_cli} -p vglloadbalancing-disabled ps --filter "status=running" --services)
$(${docker_compose_cli} -p vglloadbalancing-disabled ps --filter "status=restarting" --services)
EOF

                if [ "${running_services_counter}" -eq 4 ] || [ "${wait_for_docker_services_start_counter}" -ge 400 ]; then
                    is_waiting_for_cleanup_executed=true
                    queued_signal_code=130
                    return
                else
                    return 1
                fi
            else
                return 1
            fi
        }

        no_load_balancing_containers_are_stopped() {
            running_services_counter=0
            running_services=

            while IFS= read -r SERVICE_NAME; do
                if [ -n "${SERVICE_NAME}" ]; then
                    running_services_counter=$((running_services_counter + 1))
                fi
            done <<EOF
$(${docker_compose_cli} -p vglloadbalancing-disabled ps --filter "status=running" --services)
$(${docker_compose_cli} -p vglloadbalancing-disabled ps --filter "status=restarting" --services)
EOF


            [ "${running_services_counter}" -eq 0 ]
        }

        It 'starts the demonstration with Docker and stops it successfully'
            When call main --no-build --no-load-balancing
            The status should eq 130
            The line 1 of stdout should eq "Launching Docker services ..."
            The line 2 of stdout should eq "Waiting for DockerComposeOrchestrator with PID ${DockerComposeOrchestrator_pid} to start ... Please wait ..."
            The stderr should satisfy no_force_kill_acted
            The stderr should satisfy has_started
            The variable build should eq false
            The variable start should eq true
            The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
            The variable environment should eq "${DOCKER_ENVIRONMENT}"
            The variable docker_compose_cli should be present
            The variable exit_code should eq 130
            The variable queued_signal_code should eq 130
            Assert no_background_process_is_alive
            Assert current_location_is_at_the_base_of_the_project
            Assert no_load_balancing_containers_are_stopped
        End
    End
End