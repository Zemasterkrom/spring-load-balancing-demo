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
cd ../../../vglservice/server/docker/scripts || return 1
load_core_only=true . ./serve.sh

Describe 'Service server environment configuration'
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
                API_HOSTNAME="$(cat "$2")"
            fi
        }

        echo() {
            persisted_variable_data="$1"
            persisted_variable_data_path="$2"
        }
        
        cat() {
            %puts "loaded_test_hostname"
        }

        Context 'With environment variable test'
            Context 'Environment variable already defined'
                BeforeEach 'CONTAINER_NAME_ID=test_container;API_HOSTNAME=test_hostname'

                It 'exports the API_HOSTNAME environment variable to a file and to other processes'
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The variable API_HOSTNAME should eq test_hostname
                    The variable persisted_variable_data should eq test_hostname
                    The variable persisted_variable_data_path should not be blank
                    The variable loaded_variable_data should be undefined
                End
            End

            Context 'Environment variable not defined'
                BeforeEach 'CONTAINER_NAME_ID=test_container'

                Context 'Volume persistence file exists'
                    test() {
                        true
                    }

                    It 'reads the API_HOSTNAME environment variable from the persisted volume file'
                        When call configure_environment_variables
                        The status should be success
                        The stdout should be blank
                        The stderr should be blank
                        The variable API_HOSTNAME should eq loaded_test_hostname
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

                    BeforeEach 'CONTAINER_NAME_ID=test_container'

                    It "attempts to read the API_HOSTNAME environment variable from the persistent volume file, but uses data from the system because the file does not exist"
                        When call configure_environment_variables
                        The status should be success
                        The stdout should be blank
                        The stderr should be blank
                        The variable API_HOSTNAME should eq default_hostname
                        The variable persisted_variable_data should be blank
                        The variable persisted_variable_data_path should be blank
                        The variable loaded_variable_data should be undefined
                    End
                End
            End
        End

        Context 'Without environment variable test'
            Context 'Environment variable already defined'
                BeforeEach 'API_HOSTNAME=test_hostname'

                It 'exports the API_HOSTNAME environment variable to other processes'
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The variable API_HOSTNAME should eq test_hostname
                    The variable persisted_variable_data should be blank
                    The variable persisted_variable_data_path should be blank
                    The variable loaded_variable_data should be undefined
                End
            End

            Context 'Environment variable not defined'
                hostname() {
                    %puts "default_hostname"
                }

                It "uses fallback system data because the API_HOSTNAME environment variable isn't defined"
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The variable API_HOSTNAME should eq default_hostname
                    The variable persisted_variable_data should be blank
                    The variable persisted_variable_data_path should be blank
                    The variable loaded_variable_data should be undefined
                End
            End
        End
    End
End