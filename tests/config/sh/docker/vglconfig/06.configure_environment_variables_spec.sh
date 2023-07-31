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
cd ../../../vglconfig/server/docker/scripts || return 1
load_core_only=true . ./serve.sh

Describe 'Config server environment configuration'
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
                GIT_CONFIG_BRANCH="$(cat "$2")"
            fi
        }

        echo() {
            persisted_variable_data="$1"
            persisted_variable_data_path="$2"
        }
        
        cat() {
            %puts "loaded_test_branch"
        }

        Context 'Environment variable already defined'
            BeforeEach 'GIT_CONFIG_BRANCH=test_branch'

            It 'exports the GIT_CONFIG_BRANCH environment variable to a file and to other processes'
                When call configure_environment_variables
                The status should be success
                The stdout should be blank
                The stderr should be blank
                The variable GIT_CONFIG_BRANCH should eq test_branch
                The variable persisted_variable_data should eq test_branch
                The variable persisted_variable_data_path should not be blank
                The variable loaded_variable_data should be undefined
            End
        End

        Context 'Environment variable not defined'
            Context 'Volume persistence file exists'
                test() {
                    true
                }

                It 'reads the GIT_CONFIG_BRANCH environment variable from the persisted volume file'
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The variable GIT_CONFIG_BRANCH should eq loaded_test_branch
                    The variable persisted_variable_data should be blank
                    The variable persisted_variable_data_path should be blank
                    The variable loaded_variable_data should be undefined
                End
            End

            Context "Volume persistence file doesn't exist"
                test() {
                    false
                }

                It "attempts to read the GIT_CONFIG_BRANCH environment variable from the persistent volume file, but refers to the default master branch because the file does not exist"
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The variable GIT_CONFIG_BRANCH should eq master
                    The variable persisted_variable_data should be blank
                    The variable persisted_variable_data_path should be blank
                    The variable loaded_variable_data should be undefined
                End
            End
        End
    End
End