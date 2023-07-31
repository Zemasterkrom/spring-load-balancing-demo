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
cd ../../../vglloadbalancer/server/docker/scripts || return 1
load_core_only=true . ./serve.sh

Describe 'Load Balancer server environment configuration'
    Context 'Successful configuration'
        Mock mkdir
            true
        End

        Mock touch
            true
        End

        load_and_persist_variables() {
            if [ -n "$1" ]; then
                echo "$1" "$2"
            elif test -f "$2" && test -r "$2"; then
                LOADBALANCER_HOSTNAME="$(cat "$2")"
            fi
        }

        echo() {
            persisted_variable_data="$1"
            persisted_variable_data_path="$2"
        }
        
        cat() {
            %puts "loaded_test_hostname"
        }

        Context 'Environment variable already defined'
            BeforeEach 'LOADBALANCER_HOSTNAME=test_hostname'

            It 'exports the LOADBALANCER_HOSTNAME environment variable to a file and to other processes'
                When call configure_environment_variables
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable LOADBALANCER_HOSTNAME should eq test_hostname
                The variable persisted_variable_data should eq test_hostname
                The variable persisted_variable_data_path should not be blank
                The variable loaded_variable_data should be undefined
            End
        End

        Context 'Environment variable not defined'
            Context 'Volume persistence file exists'
                test() {
                    true
                }

                It 'reads the LOADBALANCER_HOSTNAME environment variable from the persisted volume file'
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The variable LOADBALANCER_HOSTNAME should eq loaded_test_hostname
                    The variable persisted_variable_data should be blank
                    The variable persisted_variable_data_path should be blank
                    The variable loaded_variable_data should be undefined
                End
            End

            Context "Volume persistence file doesn't exist"
                test() {
                    false
                }

                hostname() {
                    %puts "default_hostname"
                }

                It "attempts to read the LOADBALANCER_HOSTNAME environment variable from the persistent volume file, but uses data from the system because the file does not exist"
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The variable LOADBALANCER_HOSTNAME should eq default_hostname
                    The variable persisted_variable_data should be blank
                    The variable persisted_variable_data_path should be blank
                    The variable loaded_variable_data should be undefined
                End
            End
        End
    End
End