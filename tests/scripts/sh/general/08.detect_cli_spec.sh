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
    Context 'Success cases'
        Context 'CLI : docker compose'
            Mock docker
                echo "Docker Compose version v1.29.0"
            End
            
            It 'detects a compatible and available version of Docker Compose on the system'
                When call detect_compatible_available_docker_compose_cli
                The status should be success
                The stdout should eq "docker compose:1.29.0"
                The variable docker_compose_cli should eq "docker compose"
                The variable docker_compose_version should eq "1.29.0"
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
                echo "Docker Compose version v1.29.0"
            End
            
            It 'detects a compatible and available version of Docker Compose on the system'
                When call detect_compatible_available_docker_compose_cli
                The status should be success
                The stdout should eq "docker-compose:1.29.0"
                The variable docker_compose_cli should eq "docker-compose"
                The variable docker_compose_version should eq "1.29.0"
                The variable docker_detection_error should eq false
            End
        End
    End

    Context 'Error cases'
        Context 'CLI : docker compose'
            Mock docker
                echo "Docker Compose version v1.28.0"
            End
            
            It "fails since the Docker Compose version isn't compatible"
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
                echo "Docker Compose version v1.28.0"
            End
            
            It "fails since the Docker Compose version isn't compatible"
                When call detect_compatible_available_docker_compose_cli
                The status should eq 127
                The variable docker_compose_cli should be blank
                The variable docker_compose_version should be blank
                The variable docker_detection_error should eq true
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
    Context 'Success cases'
        Context 'stdout echo'
            Mock java
                echo "openjdk version \"17.0.0\""
            End

            It 'succeeds since the Java version is compatible'
                When call detect_compatible_available_java_cli
                The status should be success
                The stdout should eq "java:17.0.0"
                The variable java_cli should eq java
                The variable java_version should eq 17.0.0
            End
        End

        Context 'stderr echo'
            Mock java
                echo "openjdk version \"17.0.0\"" >&2
            End

            It 'succeeds since the Java version is compatible'
                When call detect_compatible_available_java_cli
                The status should be success
                The stdout should eq "java:17.0.0"
                The variable java_cli should eq java
                The variable java_version should eq 17.0.0
            End
        End
    End

    Context 'Error cases'
        Context 'stdout echo'
            Mock java
                echo "openjdk version \"16.9.9\""
            End

            It "fails since the Java version isn't compatible"
                When call detect_compatible_available_java_cli
                The status should eq 127
                The variable java_cli should be blank
                The variable java_version should be blank
            End
        End

        Context 'stderr echo'
            Mock java
                echo "openjdk version \"16.9.9\"" >&2
            End

            It "fails since the Java version isn't compatible"
                When call detect_compatible_available_java_cli
                The status should eq 127
                The variable java_cli should be blank
                The variable java_version should be blank
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
    Context 'Success cases'
        Mock node
            echo "v16.0.0"
        End

        It 'succeeds since the Node version is compatible'
            When call detect_compatible_available_node_cli
            The status should be success
            The stdout should eq "node:16.0.0"
            The variable node_cli should eq node
            The variable node_version should eq 16.0.0
        End
    End

    Context 'Error cases'
        Context 'stdout echo'
            Mock node
                echo "v15.9.9"
            End

            It "fails since the Node version isn't compatible"
                When call detect_compatible_available_node_cli
                The status should eq 127
                The variable node_cli should be blank
                The variable node_version should be blank
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
    Context 'Success cases'
        Mock mvn
            echo "Apache Maven 3.5.0"
        End

        It 'succeeds since the Maven version is compatible'
            When call detect_compatible_available_maven_cli
            The status should be success
            The stdout should eq "maven:3.5.0"
            The variable maven_cli should eq maven
            The variable maven_version should eq 3.5.0
        End
    End

    Context 'Error cases'
        Context 'stdout echo'
            Mock node
                echo "Apache Maven 3.4.9"
            End

            It "fails since the Maven version isn't compatible"
                When call detect_compatible_available_node_cli
                The status should eq 127
                The variable maven_cli should be blank
                The variable maven_version should be blank
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