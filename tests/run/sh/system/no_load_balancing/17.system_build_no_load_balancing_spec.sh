# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'System build'
    Mock init_shell_params
        true
    End

    Mock configure_environment_variables
        true
    End

    exit_script() {
        return "${1:-0}"
    }

    current_location_is_at_the_base_of_the_project() {
        [ -z "$(pwd | awk '/vglfront[\/\\]?$/ { print }' 2>/dev/null)" ]
    }
    
    start_with_stop_indice() {
        stop_indice="$1"
        shift
        main "$@"
    }

    BeforeEach "load_core_only=false"

    Context 'Abstract (mocked) build behavior'
        Mock mvn
            echo "$@" | sed 's/^.*-DfinalName=\([^[:space:]]\{1,\}\).*$/\1/g'
        End

        Mock npm
            echo vglfront
        End

        Context 'Build mode disabled'
            auto_detect_system_stack() {
                environment="${SYSTEM_ENVIRONMENT}"
            }

            check_file_existence() {
                if [ -z "${check_file_existence_counter}" ]; then
                    check_file_existence_counter=0
                fi

                check_file_existence_counter=$((check_file_existence_counter + 1))

                if [ "${check_file_existence_counter}" -eq "${stop_indice}" ]; then
                    return 1
                fi
            }

            It "checks that the system build isn't triggered when nothing is enabled"
                When call main --no-start --no-build --no-load-balancing
                The status should be success
                The stdout should be blank
                The variable build should eq false
                The variable start should eq false
                Assert current_location_is_at_the_base_of_the_project
            End

            Context 'Packages check behavior check'
                Mock start
                    true
                End

                check_load_balancing_packages() {
                     return 1
                }

                Context 'Missing packages auto-detection'
                    Parameters
                        1
                        2
                        3
                    End

                    It 'should enable the build mode since some packages are not built and start mode is enabled'
                        When call start_with_stop_indice "$1" --no-build --no-load-balancing
                        The status should be success
                        The lines of stdout should equal 4
                        The line 1 of stdout should eq "Building packages ..."
                        The line 2 of stdout should eq vglconfig
                        The line 3 of stdout should eq vglservice
                        The line 4 of stdout should eq vglfront
                        The stderr should eq "No Load Balancing packages are not completely built. Build mode enabled."
                        The variable build should eq true
                        The variable start should eq true
                        The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
                        The variable environment should eq "${SYSTEM_ENVIRONMENT}"
                        Assert current_location_is_at_the_base_of_the_project
                    End
                End

                Context 'Missing packages auto-detection (no missing packages)'
                    check_no_load_balancing_packages() {
                        true
                    }

                    It 'should not trigger the build of the packages since the required packages are present'
                        When call main --no-build --no-load-balancing
                        The status should be success
                        The stdout should be blank
                        The variable build should eq false
                        The variable start should eq true
                        The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
                        The variable environment should eq "${SYSTEM_ENVIRONMENT}"
                        Assert current_location_is_at_the_base_of_the_project
                    End
                End
            End
        End

        Context 'Build mode enabled'
            Context 'System requirements not met'
                Parameters
                    1
                    2
                End

                detect_compatible_available_docker_compose_cli() {
                    return 1
                }

                detect_compatible_available_java_cli() {
                    [ "${stop_indice}" -ge 1 ]
                }

                detect_compatible_available_maven_cli() {
                    [ "${stop_indice}" -ge 2 ]
                }

                detect_compatible_available_node_cli() {
                    [ "${stop_indice}" -ge 3 ]
                }

                It "checks that system build is not triggered when system requirements are not met"
                    When call start_with_stop_indice "$1" --no-start --no-load-balancing
                    The status should eq 127
                    The stdout should eq "Auto-choosing the launch method ..."
                    The stderr should eq "Unable to run the demo
${REQUIREMENTS_TEXT}"
                    The variable build should eq true
                    The variable start should eq false
                    The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
                    The variable environment should eq false
                    Assert current_location_is_at_the_base_of_the_project
                End
            End

            Context 'Build by default'
                auto_detect_system_stack() {
                    environment="${SYSTEM_ENVIRONMENT}"
                }

                check_load_balancing_packages() {
                     true
                }

                check_no_load_balancing_packages() {
                    return 1
                }

                Context 'Successful build'
                    It 'should process the build even if there are not any changes in the project'
                        When call main --no-start --no-load-balancing
                        The status should be success
                        The lines of stdout should equal 4
                        The line 1 of stdout should eq "Building packages ..."
                        The line 2 of stdout should eq vglconfig
                        The line 3 of stdout should eq vglservice
                        The line 4 of stdout should eq vglfront
                        The variable build should eq true
                        The variable start should eq false
                        The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
                        The variable environment should eq "${SYSTEM_ENVIRONMENT}"
                        Assert current_location_is_at_the_base_of_the_project
                    End
                End

                Context 'Failed build'
                    mvn() {
                        return 127
                    }

                    npm() {
                        return 127
                    }

                    It 'should fail the build correctly'
                        When call main --no-start --no-load-balancing
                        The status should eq 127
                        The lines of stdout should equal 1
                        The line 1 of stdout should eq "Building packages ..."
                        The variable build should eq true
                        The variable start should eq false
                        The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
                        The variable environment should eq "${SYSTEM_ENVIRONMENT}"
                        Assert current_location_is_at_the_base_of_the_project
                    End
                End
            End
        End
    End

    Context 'Concrete build behavior check'
        auto_detect_system_stack() {
            if detect_compatible_available_java_cli >/dev/null 2>&1 && detect_compatible_available_maven_cli >/dev/null 2>&1 && detect_compatible_available_node_cli >/dev/null 2>&1; then
                environment="${SYSTEM_ENVIRONMENT}"
            else
                return 127
            fi
        }

        It 'builds the packages correctly'
            When call main --no-start --no-load-balancing
            The status should be success
            The line 1 of stdout should eq "Building packages ..."
            The variable build should eq true
            The variable start should eq false
            The variable mode should eq "${NO_LOAD_BALANCING_MODE}"
            The variable environment should eq "${SYSTEM_ENVIRONMENT}"
            The stderr should satisfy true
            Assert current_location_is_at_the_base_of_the_project
            Assert check_no_load_balancing_packages
        End
    End
End