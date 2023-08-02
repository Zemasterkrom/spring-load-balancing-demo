# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2218
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Configure environment variables'
    Context 'Successful automatic configuration'
        Context 'General configuration'
            Parameters
                "${DOCKER_ENVIRONMENT}" "${LOAD_BALANCING_MODE}" .env
                "${DOCKER_ENVIRONMENT}" "${NO_LOAD_BALANCING_MODE}" no-load-balancing.env
                "${SYSTEM_ENVIRONMENT}" "${LOAD_BALANCING_MODE}" .env
                "${SYSTEM_ENVIRONMENT}" "${NO_LOAD_BALANCING_MODE}" no-load-balancing.env
            End

            setup_environment() {
                export LOADBALANCER_HOSTNAME=""
                export API_HOSTNAME=""
                export API_TWO_HOSTNAME=""
                export CONFIG_SERVER_URL=""

                start=true
                environment="$1"
                mode="$2"
            }

            It "auto-configures the environment variables with success"
                setup_environment "$1" "$2"
                When call configure_environment_variables
                The status should be success
                The stderr should be blank
                The variable LOADBALANCER_HOSTNAME should not be blank
                The variable API_HOSTNAME should eq "${LOADBALANCER_HOSTNAME}"
                The variable API_TWO_HOSTNAME should eq "${LOADBALANCER_HOSTNAME}"
                The variable CONFIG_SERVER_URL should not be blank
                The variable LOADBALANCER_HOSTNAME should not be blank
                The variable environment_file should eq "$3"
                The line 1 of stdout should eq "Reading environment variables ..."
                The line 2 of stdout should eq "Environment auto-configuration ..."
            End

            Context 'Load Balancing mode'
                Parameters
                    "${DOCKER_ENVIRONMENT}"
                    "${SYSTEM_ENVIRONMENT}"
                End

                setup_environment() {
                    unset EUREKA_SERVERS_URLS

                    start=true
                    environment="$1"
                    mode="${LOAD_BALANCING_MODE}"
                }

                It "auto-configures the environment variables including the EUREKA_SERVERS_URLS variable"
                    setup_environment "$1"
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be present
                    The stderr should be blank
                    The variable EUREKA_SERVERS_URLS should not be blank
                    The variable environment_file should eq .env
                End
            End

            Context 'No Load Balancing mode'
                Parameters
                    "${DOCKER_ENVIRONMENT}"
                    "${SYSTEM_ENVIRONMENT}"
                End

                setup_environment() {
                    unset EUREKA_SERVERS_URLS

                    start=true
                    environment="$1"
                    mode="${NO_LOAD_BALANCING_MODE}"
                }

                It "auto-configures the environment variables with success without the EUREKA_SERVERS_URLS variable"
                    setup_environment "$1"
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be present
                    The stderr should be blank
                    The variable EUREKA_SERVERS_URLS should be undefined
                    The variable environment_file should eq no-load-balancing.env
                End
            End
        End

        Context 'System-dependent configuration'
            Context 'General configuration'
                Parameters
                    "${LOAD_BALANCING_MODE}" .env
                    "${NO_LOAD_BALANCING_MODE}" no-load-balancing.env
                End

                setup_environment() {
                    export LOADBALANCER_HOSTNAME=""
                    export API_HOSTNAME=""
                    export API_TWO_HOSTNAME=""
                    export CONFIG_SERVER_URL=""

                    start=true
                    environment="${SYSTEM_ENVIRONMENT}"
                    mode="$1"
                }

                It "removes unnecessary environment variables as we are using a system dependent implementation"
                    setup_environment "$1"
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be present
                    The stderr should be blank
                    The variable DB_URL should be undefined
                    The variable DB_USERNAME should be undefined
                    The variable DB_PASSWORD should be undefined
                    The variable DB_PORT should be undefined
                    The variable environment_file should eq "$2"
                End
            End

            Context 'Load Balancing mode'
                setup_environment() {
                    unset EUREKA_SERVERS_URLS

                    start=true
                    environment="${SYSTEM_ENVIRONMENT}"
                    mode="${LOAD_BALANCING_MODE}"
                }

                It "ensures that the EUREKA_SERVERS_URLS variable remains defined even if we are using a system implementation"
                    setup_environment
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be present
                    The stderr should be blank
                    The variable EUREKA_SERVERS_URLS should not be blank
                    The variable environment_file should eq .env
                End
            End

            Context 'No Load Balancing mode'
                setup_environment() {
                    unset EUREKA_SERVERS_URLS

                    start=true
                    environment="${SYSTEM_ENVIRONMENT}"
                    mode="${NOLOAD_BALANCING_MODE}"
                }

                It "ensures that the EUREKA_SERVERS_URLS variable remains undefined even if we are using a system implementation"
                    setup_environment
                    When call configure_environment_variables
                    The status should be success
                    The stdout should be present
                    The stderr should be blank
                    The variable EUREKA_SERVERS_URLS should be undefined
                    The variable environment_file should eq no-load-balancing.env
                End
            End
        End
    End

    Context 'Fallback configuration'
        Parameters
            "${LOAD_BALANCING_MODE}" .env
            "${NO_LOAD_BALANCING_MODE}" no-load-balancing.env
        End

        git() {
            false
        }

        hostname() {
            false
        }

        setup_environment() {
            start=true
            environment="$1"
        }

        It "configures the system-dependant properties using the system environment instead on relying on the environment file"
            setup_environment "$1"
            When call configure_environment_variables
            The status should be success
            The stdout should be present
            The stderr should be blank
            The variable LOADBALANCER_HOSTNAME should eq localhost
            The variable API_HOSTNAME should eq "${LOADBALANCER_HOSTNAME}"
            The variable API_TWO_HOSTNAME should eq "${API_HOSTNAME}"
        End
    End

    Context 'Ignore configuration if not needed'
        setup_environment() {
            start=false
        }

        It "ignores the configuration because the demo launch is disabled"
            setup_environment
            When call configure_environment_variables
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End
    End
End