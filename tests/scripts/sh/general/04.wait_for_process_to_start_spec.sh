# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Wait for process to start'
    Context 'consistence checks'
        Parameters
            Test
            TestWithMultipleWords
            TestWithNumber1
            Test_With_Underscore
        End


        Context 'check without timeout for the current process'
            It 'directly returns since the current process exists'
                When call wait_for_process_to_start "$1" $$ 0
                The status should be success
                The stdout should eq "Waiting for $1 with PID $$ to start ... Please wait ..."
                The variable "$1_stime" should be blank
            End
        End

        Context 'check with timeout for the current process'
            It 'directly returns since the current process exists'
                When call wait_for_process_to_start "$1" $$ 5
                The status should be success
                The stdout should eq "Waiting for $1 with PID $$ to start ... Please wait ..."
                The variable "$1_stime" should be blank
            End


            Context 'get_process_info : mocked version (process creation)'
                Mock get_process_info
                    if [ -f "${TMP_DATA_FILE_LOCATION}_PID_test" ]; then
                        echo true
                    fi
                End

                create_tmp_pid_file() {
                    { sleep 2; touch "${TMP_DATA_FILE_LOCATION}_PID_test"; } &
                }

                rm_tmp_pid_file() {
                    rm "${TMP_DATA_FILE_LOCATION}_PID_test" 2>/dev/null || true
                }

                BeforeEach create_tmp_pid_file
                AfterEach rm_tmp_pid_file

                It 'returns as soon as the process starts'
                    When call wait_for_process_to_start "$1" $$ 5
                    The status should be success
                    The stdout should eq "Waiting for $1 with PID $$ to start ... Please wait ..."
                End

                Context 'get_process_info : mocked version (timeout simulation)'
                    Mock get_process_info
                        true
                    End

                    It "fails since the process hasn't started"
                        When call wait_for_process_to_start "$1" $$ 5
                        The status should eq 3
                        The stdout should eq "Waiting for $1 with PID $$ to start ... Please wait ..."
                        The stderr should eq "$1 with PID $$ has not started. Cannot continue."
                    End
                End
            End
        End
    End

    Context 'Basic fail cases'
        Context 'Incorrect service name'
            Parameters
                "Spaces are not allowed"
                "_UnderscoreAtBeginningIsNotAllowed"
                "Special'CharactersAreNotAllowed'*"
            End

            It 'fails since the service name is badly formatted'
                When call wait_for_process_to_start "$1" 0 0
                The status should eq 2
            End
        End

        Context 'Incorrect timeout'
            Parameters
                -1
                " -1"
                "-a"
                a
                "a a"
            End

            It 'fails since the timeout is invalid'
                When call wait_for_process_to_start FailWithInvalidTimeout 0 "$1"
                The status should eq 2
            End
        End

        Context 'Incorrect PID'
            Parameters
                " -1"
                "-a"
                a
                "a a"
            End

            It 'fails since the PID is invalid'
                When call wait_for_process_to_start FailWithInvalidPID "$1" 0
                The status should eq 2
            End
        End
    End
End