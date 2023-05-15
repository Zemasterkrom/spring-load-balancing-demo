# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Detect Docker Compose CLI'
    Context 'Success cases with valid and compatible versions'
        Parameters
            "Docker Compose version v1.29.0 1.0.0" "1.29.0"
            "Docker Compose version v1.29.0" "1.29.0"
            "v1.29.1" "1.29.1"
            "1.29" "1.29.0"
            "Docker Compose version v2.0" "2.0.0"
            "v2.0.0" "2.0.0"
            "2.0.1" "2.0.1"
            "Docker Compose version v2.1.0" "2.1.0"
            "v2.1.0-alpha" "2.1.0"
            "2.1.0-alpha" "2.1.0"
        End

        Context 'CLI : docker compose'
            Mock docker
                echo "${version_string}"
            End
            
            It "detects a compatible and available version of Docker Compose on the system ($1 : $2)"
                export version_string="$1"
                When call detect_compatible_available_docker_compose_cli
                The status should be success
                The stdout should eq "docker compose:$2"
                The variable docker_compose_cli should eq "docker compose"
                The variable docker_compose_version should eq "$2"
                The variable docker_detection_error should eq false
            End
        End

        Context 'CLI : docker-compose'
            Mock docker
                if [ "$1" = "compose" ]; then
                    return 1
                fi
            End

            Mock docker-compose
                echo "${version_string}"
            End
            
            It "detects a compatible and available version of Docker Compose on the system ($1 : $2)"
                export version_string="$1"
                When call detect_compatible_available_docker_compose_cli
                The status should be success
                The stdout should eq "docker-compose:$2"
                The variable docker_compose_cli should eq "docker-compose"
                The variable docker_compose_version should eq "$2"
                The variable docker_detection_error should eq false
            End
        End
    End

    Context 'Error cases'
        Context 'Invalid / incompatible versions'
            Parameters
                "No version"
                "Docker Compose version"
                "Docker Compose version 2-alpha"
                "Docker Compose version 2a.6-alpha"
                "Docker Compose version a.2-alpha"
                "Docker Compose version 2"
                "Docker Compose version 1.28"
                "Docker Compose version 1.28.9"
                "Docker Compose version 1.0"
                "Docker Compose version 0.1"
                "Docker Compose version 0.1.0"
                "Docker Compose version 0.1.1"
                "Docker Compose version 0.1.1-alpha"
                "2"
                "1.28"
                "1.28.9"
                "0.1"
                "0.1.0"
                "0.1.1"
                "0.1.1-alpha"
            End

            Context 'CLI : docker compose'
                Mock docker
                    echo "${version_string}"
                End
                
                It "fails since the Docker Compose version isn't compatible ($1)"
                    export version_string="$1"
                    When call detect_compatible_available_docker_compose_cli
                    The status should eq 127
                    The variable docker_compose_cli should be blank
                    The variable docker_compose_version should be blank
                    The variable docker_detection_error should eq true
                End
            End

            Context 'CLI : docker-compose'
                Mock docker
                    if [ "$1" = "compose" ]; then
                        return 1
                    fi
                End

                Mock docker-compose
                    echo "${version_string}"
                End
                
                It "fails since the Docker Compose version isn't compatible ($1)"
                    export version_string="$1"
                    When call detect_compatible_available_docker_compose_cli
                    The status should eq 127
                    The variable docker_compose_cli should be blank
                    The variable docker_compose_version should be blank
                    The variable docker_detection_error should eq true
                End
            End
        End

        Context 'Docker daemon system error'
            Mock docker
                return 1
            End

            It "fails since the Docker daemon isn't available"
                When call detect_compatible_available_docker_compose_cli
                The status should eq 126
                The variable docker_compose_cli should be blank
                The variable docker_compose_version should be blank
                The variable docker_detection_error should eq true
                The variable docker_detection_system_error should eq true
            End
        End

        Context 'Docker Compose system error'
            Mock docker
                if [ "$1" = "compose" ]; then
                    return 1
                fi
            End

            Mock docker-compose
                return 1
            End

            It "fails since the Docker daemon isn't available"
                When call detect_compatible_available_docker_compose_cli
                The status should eq 126
                The variable docker_compose_cli should be blank
                The variable docker_compose_version should be blank
                The variable docker_detection_error should eq true
                The variable docker_detection_system_error should eq true
            End
        End
    End
End

Describe 'Detect Java CLI'
    Context 'Success cases with valid and compatible versions'
        Parameters
            'openjdk version "17.0.0" "10.0.0"' "17.0.0"
            'openjdk version "17.0.0"' "17.0.0"
            'openjdk version 17.0.0' "17.0.0"
            'openjdk version "17.0.1"' "17.0.1"
            'openjdk version 17.0.1' "17.0.1"
            'openjdk version "17.1.1"' "17.1.1"
            'openjdk version 17.1.1' "17.1.1"
            'openjdk version "18.0.0"' "18.0.0"
            'openjdk version 18.0.0' "18.0.0"
            'openjdk version "17.0"' "17.0.0"
            'openjdk version 17.0' "17.0.0"
            'openjdk version "17.0.1"' "17.0.1"
            'openjdk version 17.0.1' "17.0.1"
            'openjdk version 17.0.1-alpha' "17.0.1"
            'openjdk version "17.0.1-alpha"' "17.0.1"
            'openjdk version "18.0.1-alpha"' "18.0.1"
            'openjdk version 19.0.1-alpha' "19.0.1"
            'openjdk version 19.1.1-alpha' "19.1.1"
        End

        Context 'stdout echo'
            Mock java
                echo "${version_string}"
            End

            It "succeeds since the Java version is compatible ($1 : $2)"
                export version_string="$1"
                When call detect_compatible_available_java_cli
                The status should be success
                The stdout should eq "java:$2"
                The variable java_cli should eq java
                The variable java_version should eq "$2"
            End
        End

        Context 'stderr echo'
            Mock java
                echo "${version_string}" >&2
            End

            It "succeeds since the Java version is compatible ($1 : $2)"
                export version_string="$1"
                When call detect_compatible_available_java_cli
                The status should be success
                The stdout should eq "java:$2"
                The variable java_cli should eq java
                The variable java_version should eq "$2"
            End
        End
    End

    Context 'Error cases'
        Context 'Invalid / incompatible version'
            Parameters
                "No version"
                'openjdk version'
                'openjdk version "17"'
                'openjdk version 17'
                'openjdk version "17-alpha"'
                'openjdk version 17-alpha'
                'openjdk version "17.a"'
                'openjdk version 17.a'
                'openjdk version "17.a.b"'
                'openjdk version 17.a.b'
                'openjdk version "17.a-alpha"'
                'openjdk version 17.a-alpha'
                'openjdk version "17.a.b-alpha"'
                'openjdk version 17.a.b-alpha'
                'openjdk version "16.9.9"'
                'openjdk version 16.9.9'
                'openjdk version "16.9.9-alpha"'
                'openjdk version 16.9.9-alpha'
                'openjdk version "16.9"'
                'openjdk version 16.9'
                'openjdk version "1.0.1"'
                'openjdk version 1.0.1'
                'openjdk version "1.1.1"'
                'openjdk version 1.1.1'
                'openjdk version "1.0"'
                'openjdk version 1.0'
            End

            Context 'stdout echo'
                Mock java
                    echo "${version_string}"
                End

                It "fails since the Java version isn't compatible ($1)"
                    export version_string="$1"
                    When call detect_compatible_available_java_cli
                    The status should eq 127
                    The variable java_cli should be blank
                    The variable java_version should be blank
                End
            End

            Context 'stderr echo'
                Mock java
                    echo "${version_string}" >&2
                End

                It "fails since the Java version isn't compatible ($1)"
                    export version_string="$1"
                    When call detect_compatible_available_java_cli
                    The status should eq 127
                    The variable java_cli should be blank
                    The variable java_version should be blank
                End
            End
        End

        Context 'Java system error'
            Mock java
                return 1
            End

            It "fails since a Java system error occurs"
                When call detect_compatible_available_java_cli
                The status should eq 126
                The variable java_cli should be blank
                The variable java_version should be blank
            End
        End
    End
End

Describe 'Detect Node CLI'
    Context 'Success cases with valid and compatible versions'
        Parameters
            "v16.0 10.0" "16.0.0"
            "v16.0" "16.0.0"
            "v16.0-alpha" "16.0.0"
            "v16.0.0" "16.0.0"
            "v16.0.0-alpha" "16.0.0"
            "16.0.0" "16.0.0"
            "v16.0.1" "16.0.1"
            "v16.0.1-alpha" "16.0.1"
            "16.0.1" "16.0.1"
            "v16.1.0" "16.1.0"
            "v16.1.0-alpha" "16.1.0"
            "16.1.0" "16.1.0"
            "v17.0.0" "17.0.0"
            "v17.0.0-alpha" "17.0.0"
            "17.0.0" "17.0.0"
            "v17.0.1" "17.0.1"
            "v17.0.1-alpha" "17.0.1"
            "17.0.1" "17.0.1"
            "v17.1.1" "17.1.1"
            "v17.1.1-alpha" "17.1.1"
            "17.1.1" "17.1.1"
        End

        Mock node
            echo "${version_string}"
        End

        It "succeeds since the Node version is compatible ($1 : $2)"
            export version_string="$1"
            When call detect_compatible_available_node_cli
            The status should be success
            The stdout should eq "node:$2"
            The variable node_cli should eq node
            The variable node_version should eq "$2"
        End
    End

    Context 'Error cases'
        Context 'Invalid / incompatible versions'
            Parameters
                "v"
                "v15.9.9-alpha"
                "v15.9.9"
                "v15.9.0"
                "v15.9"
                "v15"
                "15.9.9"
                "15.9.0"
                "15.9"
                "15"
                "v14.9.9"
                "v14.9.0"
                "v14.9"
                "v14"
                "14.9.9"
                "14.9.0"
                "14.9"
                "14"
                "v1.9.9"
                "v1.9.0"
                "v1.9"
                "v1"
                "1.9.9"
                "1.9.0"
                "1.9"
                "1"
                "v16.a"
                "v16.a-alpha"
                "v16.a.b"
                "16.a.b-alpha"
                "16.a"
                "16.a-alpha"
                "16.a.b"
                "16.a.b-alpha"
            End

            Context 'stdout echo'
                Mock node
                    echo "${version_string}"
                End

                It "fails since the Node version isn't compatible ($1)"
                    export version_string="$1"
                    When call detect_compatible_available_node_cli
                    The status should eq 127
                    The variable node_cli should be blank
                    The variable node_version should be blank
                End
            End
        End

        Context 'Node system error'
            Mock node
                return 1
            End

            It "fails since a Node system error occurs"
                When call detect_compatible_available_node_cli
                The status should eq 126
                The variable node_cli should be blank
                The variable node_version should be blank
            End
        End
    End
End

Describe 'Detect Maven CLI'
    Context 'Success cases with valid and compatible versions'
        Parameters
            "Apache Maven 3.5 1.0" "3.5.0"
            "Apache Maven 3.5" "3.5.0"
            "Apache Maven 3.5.0" "3.5.0"
            "Apache Maven 3.5.2" "3.5.2"
            "Apache Maven 3.5.3-alpha-1" "3.5.3"
            "Apache Maven 3.5.4-beta-2" "3.5.4"
            "Apache Maven 3.6.0-SNAPSHOT" "3.6.0"
            "Apache Maven 3.6.1-rc-1" "3.6.1"
            "Apache Maven 3.6.2" "3.6.2"
            "Apache Maven 3.6.3-alpha-1" "3.6.3"
            "Apache Maven 3.7.0-SNAPSHOT" "3.7.0"
            "Apache Maven 3.7.1-beta-1" "3.7.1"
            "Apache Maven 4.0.0-alpha-1" "4.0.0"
            "Apache Maven 4.0.0-SNAPSHOT" "4.0.0"
            "Apache Maven 4.0.0-rc-1" "4.0.0"
            "Apache Maven 4.0.0" "4.0.0"
            "Apache Maven 5.0.0-alpha-1" "5.0.0"
            "Apache Maven 5.0.0-SNAPSHOT" "5.0.0"
            "Apache Maven 5.0.0-rc-1" "5.0.0"
            "Apache Maven 5.0.0" "5.0.0"
            "Apache Maven 5.1.0-SNAPSHOT" "5.1.0"
            "Apache Maven 5.1.1-alpha-1" "5.1.1"
            "Apache Maven 5.2.0-beta-2" "5.2.0"
        End

        Mock mvn
            echo "${version_string}"
        End

        It "succeeds since the Maven version is compatible ($1 : $2)"
            export version_string="$1"
            When call detect_compatible_available_maven_cli
            The status should be success
            The stdout should eq "maven:$2"
            The variable maven_cli should eq maven
            The variable maven_version should eq "$2"
        End
    End

    Context 'Error cases'
        Context 'Invalid / incompatible versions'
            Parameters
                "Apache Maven"
                "Apache Maven 3"
                "Apache Maven 3.a"
                "Apache Maven 3.a-alpha"
                "Apache Maven 3.a.b"
                "Apache Maven 3.a.b-alpha"
                "Apache Maven 3.0.5"
                "Apache Maven 3.2.3-SNAPSHOT"
                "Apache Maven 3.2.5-beta"
                "Apache Maven 3.4.0-SNAPSHOT"
                "Apache Maven 3.4.1-alpha-1"
                "Apache Maven 3.4.2-RC-2"
                "Apache Maven 3.4.3-SNAPSHOT"
                "Apache Maven 3.4.4-beta-1"
                "Apache Maven 3.4.5-SNAPSHOT"
                "Apache Maven 3.4.6-alpha-2"
                "Apache Maven 3.4.7-RC-1"
                "Apache Maven 3.4.8"
                "Apache Maven 3.4.9-SNAPSHOT"
                "Apache Maven 3.4.10-beta-3"
                "Apache Maven 3.4.11-SNAPSHOT"
                "Apache Maven 3.4.12-alpha-1"
                "Apache Maven 3.4.13-RC-2"
                "Apache Maven 3.4.14-SNAPSHOT"
                "Apache Maven 3.4.15-beta-1"
                "Apache Maven 3.4.16-SNAPSHOT"
            End

            Context 'stdout echo'
                Mock node
                    echo "Apache Maven 3.4.9"
                End

                It "fails since the Maven version isn't compatible ($1)"
                    When call detect_compatible_available_node_cli
                    The status should eq 127
                    The variable maven_cli should be blank
                    The variable maven_version should be blank
                End
            End
        End

        Context 'Maven system error'
            Mock mvn
                return 1
            End

            It "fails since a Maven system error occurs"
                When call detect_compatible_available_maven_cli
                The status should eq 126
                The variable maven_cli should be blank
                The variable maven_version should be blank
            End
        End
    End
End

Describe 'Auto-choose system stack'
    Context 'Success cases'
        Context 'Auto-choose with Docker'
            detect_compatible_available_docker_compose_cli() {
                docker_compose_cli="docker compose"
                docker_compose_version="1.29.0"

                echo "docker compose:1.29.0"
            }

            It 'chooses Docker since the Docker Compose version is available and compatible'
                When call auto_detect_system_stack
                The status should be success
                The line 1 of stdout should eq "Auto-choosing the launch method ..."
                The line 2 of stdout should eq "Docker Compose (docker compose) version 1.29.0"
                The variable environment should eq "${DOCKER_ENVIRONMENT}"
            End
        End

        Context 'Auto-choose with Java, Maven and Node'
            detect_compatible_available_docker_compose_cli() {
                return 1
            }

            detect_compatible_available_java_cli() {
                java_cli="java"
                java_version="17.0.0"

                echo "java:17.0.0"
            }

            detect_compatible_available_maven_cli() {
                maven_cli="maven"
                maven_version="3.5.0"

                echo "maven:3.5.0"
            }

            detect_compatible_available_node_cli() {
                node_cli="node"
                node_version="16.0.0"

                echo "node:16.0.0"
            }

            It "chooses the system environment since the Docker Compose version isn't compatible"
                When call auto_detect_system_stack
                The status should be success
                The line 1 of stdout should eq "Auto-choosing the launch method ..."
                The line 2 of stdout should eq "Java version 17.0.0"
                The line 3 of stdout should eq "Maven version 3.5.0"
                The line 4 of stdout should eq "Node version 16.0.0"
                The variable environment should eq "${SYSTEM_ENVIRONMENT}"
            End
        End
    End

    Context 'Error cases'
        Context 'Not any system requirements matched'
            detect_compatible_available_docker_compose_cli() {
                return 1
            }

            detect_compatible_available_java_cli() {
                return 1
            }

            detect_compatible_available_maven_cli() {
                return 1
            }

            detect_compatible_available_node_cli() {
                return 1
            }

            It 'fails because no required system components are present'
                When call auto_detect_system_stack
                The status should eq 127
                The stdout should eq "Auto-choosing the launch method ..."
                The line 1 of stderr should eq "Unable to run the demo"
                The line 2 of stderr should eq "Required : Docker Compose >= 1.29 or Java >= 17 with Maven >= 3.5 and Node >= 16"
            End
        End

        Context "Java version not matched when Docker can't be used"
            detect_compatible_available_docker_compose_cli() {
                return 1
            }

            detect_compatible_available_java_cli() {
                return 1
            }

            detect_compatible_available_maven_cli() {
                true
            }

            detect_compatible_available_node_cli() {
                true
            }

            It "fails because Java version isn't compatible"
                When call auto_detect_system_stack
                The status should eq 127
                The stdout should eq "Auto-choosing the launch method ..."
                The line 1 of stderr should eq "Unable to run the demo"
                The line 2 of stderr should eq "Required : Docker Compose >= 1.29 or Java >= 17 with Maven >= 3.5 and Node >= 16"
            End
        End

        Context "Node version not matched when Docker can't be used"
            detect_compatible_available_docker_compose_cli() {
                return 1
            }

            detect_compatible_available_java_cli() {
                true
            }

            detect_compatible_available_maven_cli() {
                true
            }

            detect_compatible_available_node_cli() {
                return 1
            }

            It "fails because Node version isn't compatible"
                When call auto_detect_system_stack
                The status should eq 127
                The stdout should eq "Auto-choosing the launch method ..."
                The line 1 of stderr should eq "Unable to run the demo"
                The line 2 of stderr should eq "Required : Docker Compose >= 1.29 or Java >= 17 with Maven >= 3.5 and Node >= 16"
            End
        End

        Context "Maven version not matched when Docker can't be used"
            detect_compatible_available_docker_compose_cli() {
                return 1
            }

            detect_compatible_available_java_cli() {
                true
            }
            
            detect_compatible_available_maven_cli() {
                return 1
            }

            detect_compatible_available_node_cli() {
                true
            }

            It "fails because Maven version isn't compatible"
                When call auto_detect_system_stack
                The status should eq 127
                The stdout should eq "Auto-choosing the launch method ..."
                The line 1 of stderr should eq "Unable to run the demo"
                The line 2 of stderr should eq "Required : Docker Compose >= 1.29 or Java >= 17 with Maven >= 3.5 and Node >= 16"
            End
        End
    End
End