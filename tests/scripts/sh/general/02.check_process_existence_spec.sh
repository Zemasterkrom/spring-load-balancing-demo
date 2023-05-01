# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Check process existence'
    Context 'Success cases'
        It 'returns directly since the current process exists'
            When call check_process_existence "" $$
            The status should be success
        End

        It 'directly returns since the custom check command succeeds'
            When call check_process_existence true $$
            The status should be success
        End

        It 'directly returns since the custom check command succeeds, even if no PID is filled in'
            When call check_process_existence true ""
            The status should be success
        End

        It "returns directly since the custom check command succeeds, even the PID isn't associated to a real process"
            When call check_process_existence true 999999
            The status should be success
        End

        It 'returns directly since the basic check succeed'
            When call check_process_existence "(exit 1)" $$
            The status should be success
        End
    End

    Context 'Error cases'
        Context 'Inexistent process'
            Mock get_process_info
                true
            End
        
            It "fails since the process doesn't exist"
                When call check_process_existence "" 999999
                The status should eq 3
            End
        End

        Context 'Inexistent process'
            Mock get_process_info
                true
            End
        
            It "fails since the process doesn't exist and the custom check command fails"
                When call check_process_existence "(exit 1)" 999999
                The status should eq 3
            End
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

            It 'tries to check with an invalid PID'
                When call get_process_info "" $1
                The status should eq 2
            End
        End
    End
End