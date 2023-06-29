# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Docker build (Load Balancing)'
    Mock init_shell_params
        set -e
    End

    Mock configure_environment_variables
        true
    End

    current_location_is_at_the_base_of_the_project() {
        [ -z "$(pwd | awk '/vglfront[\/\\]?$/ { print }' 2>/dev/null)" ]
    }

    exit_script() {
        return "${1:-0}"
    }

    BeforeEach "source_only=false"

    Context 'Abstract (mocked) build behavior check'
        Context 'Build mode disabled'
            Mock auto_detect_system_stack
                true
            End

            Mock eval_script
                echo "Docker build triggered"
            End
                    
            It "checks that Docker isn't triggered"
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

        Context 'Build mode enabled'
            Mock auto_detect_system_stack
                environment="${DOCKER_ENVIRONMENT}"
                docker_compose_cli="docker"
            End

            Context 'Successful build'
                eval_script() {
                    if ! echo "$1" | grep -q docker-compose-no-load-balancing.yml && echo "$1" | grep -q build ; then
                        echo "Docker build (load-balancing) triggered"
                    fi
                }
                    
                It 'checks that Docker is triggered'
                    When call main --no-start
                    The status should be success
                    The lines of stdout should equal 2
                    The line 1 of stdout should eq "Building packages and images ..."
                    The line 2 of stdout should eq "Docker build (load-balancing) triggered"
                    The variable build should eq true
                    The variable start should eq false
                    The variable mode should eq "${LOAD_BALANCING_MODE}"
                    The variable environment should eq "${DOCKER_ENVIRONMENT}"
                    Assert current_location_is_at_the_base_of_the_project
                End
            End

            Context 'Failed build'
                eval_script() {
                    if ! echo "$1" | grep -q docker-compose-no-load-balancing.yml && echo "$1" | grep -q build ; then
                        echo "Docker build (load-balancing) triggered"
                        return 127
                    fi
                }
                    
                It 'checks that Docker build fails correctly'
                    When call main --no-start
                    The status should eq 127
                    The lines of stdout should equal 2
                    The line 1 of stdout should eq "Building packages and images ..."
                    The line 2 of stdout should eq "Docker build (load-balancing) triggered"
                    The variable build should eq true
                    The variable start should eq false
                    The variable mode should eq "${LOAD_BALANCING_MODE}"
                    The variable environment should eq "${DOCKER_ENVIRONMENT}"
                    Assert current_location_is_at_the_base_of_the_project
                End
            End
        End
    End

    Context 'Concrete build behavior check'
        auto_detect_system_stack() {
            if detect_compatible_available_docker_compose_cli >/dev/null 2>&1; then
                environment="${DOCKER_ENVIRONMENT}"
            else
                return 127
            fi
        }

        It 'builds the images correctly'
            When call main --no-start
            The status should be success
            The line 1 of stdout should eq "Building packages and images ..."
            The variable build should eq true
            The variable start should eq false
            The variable mode should eq "${LOAD_BALANCING_MODE}"
            The variable environment should eq "${DOCKER_ENVIRONMENT}"
            The stderr should satisfy true
            Assert current_location_is_at_the_base_of_the_project
        End
    End
End