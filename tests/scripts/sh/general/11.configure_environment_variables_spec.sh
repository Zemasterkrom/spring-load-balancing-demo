# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Configure environment variables'
    contains_auto_configuration_text() {
        printf "%s" "$1" | tail -n 1 | grep "Environment auto-configuration ..."
    }

    configure_environment_variables_with_mode() {
        start=true
        mode="$1"
        configure_environment_variables
    }

    Context 'Environment configuration enabled because start is enabled'
        Parameters
            "${LOAD_BALANCING_MODE}" .env
            "${NO_LOAD_BALANCING_MODE}" no-load-balancing.env
        End

        Context "Docker environment"
            BeforeEach "environment=${DOCKER_ENVIRONMENT}"

            It 'configures the environment variables with success without trying to modify the default ones'
                When call configure_environment_variables_with_mode "$1"
                The status should be success
                The line 1 of stdout should eq "Reading environment variables ..."
                The result of function contains_auto_configuration_text should be successful
                The variable environment_file should eq "$2"
            End

            Describe 'Software fail'
                Mock git
                    return 1
                End

                Mock hostname
                    return 1
                End

                It 'configures the environment variables and reverts to the default settings for the git branch and hostname'
                    When call configure_environment_variables_with_mode "$1"
                    The status should be success
                    The line 1 of stdout should eq "Reading environment variables ..."
                    The result of function contains_auto_configuration_text should be successful
                    The variable environment_file should eq "$2"
                    The variable GIT_CONFIG_BRANCH should eq master
                    The variable LOADBALANCER_HOSTNAME should eq localhost
                    The variable API_HOSTNAME should eq localhost
                    The variable API_TWO_HOSTNAME should eq localhost
                End
            End
        End

        Context 'System environment'
            BeforeEach "environment=${SYSTEM_ENVIRONMENT}"

            It 'configures the environment variables with success without trying to modify the default ones'
                When call configure_environment_variables_with_mode "$1"
                The status should be success
                The line 1 of stdout should eq "Reading environment variables ..."
                The result of function contains_auto_configuration_text should be successful
                The variable DB_URL should be undefined
                The variable DB_USERNAME should be undefined
                The variable DB_PASSWORD should be undefined
                The variable DB_PORT should be undefined
                The variable environment_file should eq "$2"
            End

            Context 'Software fail'
                Mock git
                    return 1
                End

                Mock hostname
                    return 1
                End

                It 'configures the environment variables and reverts to the default settings for the git branch and hostname'
                    When call configure_environment_variables_with_mode "$1"
                    The status should be success
                    The line 1 of stdout should eq "Reading environment variables ..."
                    The result of function contains_auto_configuration_text should be successful
                    The variable environment_file should eq "$2"
                    The variable GIT_CONFIG_BRANCH should eq master
                    The variable LOADBALANCER_HOSTNAME should eq localhost
                    The variable API_HOSTNAME should eq localhost
                    The variable API_TWO_HOSTNAME should eq localhost
                    The variable DB_URL should be undefined
                    The variable DB_USERNAME should be undefined
                    The variable DB_PASSWORD should be undefined
                    The variable DB_PORT should be undefined
                End
            End
        End  
    End

    Context 'Environment configuration disabled because start is disabled'
        try_to_start_configuring_environment_without_start_enabled() {
            start=false
            configure_environment_variables
        }

        It "doesn't configures the environment since start is disabled"
            When call try_to_start_configuring_environment_without_start_enabled
            The stdout should be blank
            The status should be success
            The variable environment_file should be undefined
        End
    End
End