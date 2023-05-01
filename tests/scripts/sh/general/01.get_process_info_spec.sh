# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Retrieve process info'
    Context 'Success cases'
        It 'retrieves the ps info of the current process (a process that exists)'
            When call get_process_info $$
            The status should be success
            The stdout should be present
        End
    End

    Context 'Error cases'
        It 'retrieves the ps info of an inexistent process'
            When call get_process_info 999999999
            The status should eq 3
            The stdout should be blank
        End

        Context 'Invalid identifiers'
            Parameters
                ""
                a
                "a 1 a"
                "1 a a"
                "1 "
                "a -1 a"
                "-1 a a"
                "-1 "
                -1
            End

            It 'tries to retrieve the ps info with an invalid identifier'
                When call get_process_info "$1"
                The status should eq 2
                The stdout should be blank
            End
        End
    End
End