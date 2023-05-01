# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Wait for process to stop'
    Describe 'consistence checks'
        Parameters
            Test
            TestWithMultipleWords
            TestWithNumber1
            Test_With_Underscore
        End

        Describe 'check without timeout for the created process'
            check_process_existence() {
                return 1
            }

            It 'directly returns since the started process is already stopped'
                When call wait_for_process_to_stop "$1" $$ 0
                The status should be success
                The stdout should eq "Waiting for $1 with PID $$ to stop (0 seconds) ..."
            End
        End

        Describe 'check with timeout for the created process'
            Describe 'Successful wait'
                check_process_existence() {
                    if [ -z "${check_process_existence_exec_count}" ]; then
                        check_process_existence_exec_count=0
                    fi

                    check_process_existence_exec_count=$((check_process_existence_exec_count + 1))

                    if [ "${check_process_existence_exec_count}" -eq 5 ]; then
                        return 1
                    fi

                    return
                }

                It 'returns on the timeout limit since the process has stopped within the timeout interval'
                    When call wait_for_process_to_stop "$1" $$ 5
                    The status should be success
                    The stdout should eq "Waiting for $1 with PID $$ to stop (5 seconds) ..."
                End
            End

            Describe 'Failed wait'
                check_process_existence() {
                    return
                }

                It 'fails since the process has not started within the timeout interval'
                    When call wait_for_process_to_stop "$1" $$ 5
                    The status should eq 3
                    The stdout should eq "Waiting for $1 with PID $$ to stop (5 seconds) ..."
                    The stderr should eq "Wait timeout exceeded for $1 with PID $$"
                End
            End
        End
    End

    Describe 'Basic fail cases'
        Describe 'Incorrect service name'
            Parameters
                "Spaces are not allowed"
                "_UnderscoreAtBeginningIsNotAllowed"
                "Special'CharactersAreNotAllowed'*"
            End

            It 'fails since the service name is badly formatted'
                When call wait_for_process_to_stop "$1" 0 0
                The status should eq 2
            End
        End

        Describe 'Incorrect timeout'
            Parameters
                -1
                " -1"
                "-a"
                a
                "a a"
            End

            It 'fails since the timeout is invalid'
                When call wait_for_process_to_stop FailWithInvalidTimeout 0 "$1"
                The status should eq 2
            End
        End

        Describe 'Incorrect PID'
            Parameters
                " -1"
                "-a"
                a
                "a a"
            End

            It 'fails since the PID is invalid'
                When call wait_for_process_to_stop FailWithInvalidPID "$1" 0
                The status should eq 2
            End
        End
    End
End