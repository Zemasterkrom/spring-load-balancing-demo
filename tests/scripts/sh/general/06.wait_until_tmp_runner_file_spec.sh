# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Wait until temporary runner file is ready'
    It 'directly returns since the process exists, and the temporary file too'
        When call wait_until_tmp_runner_file_exists DirectTest "${TMP_DATA_FILE}" $$ 0
        The status should be success
        The stdout should eq "Waiting for DirectTest to create the ${TMP_DATA_FILE_LOCATION} file (0 seconds) ..."
        The variable DirectTest_checked_tmp_runner_file should eq true
        The path "${TMP_DATA_FILE_LOCATION}" should not be exist
    End

    Describe 'Wait with tmp file creation'
        create_another_tmp_runner_file() {
            { sleep 2 && touch "${TMP_DATA_FILE_LOCATION}_2"; } &
        }

        rm_another_tmp_runner_file() {
            rm "${TMP_DATA_FILE_LOCATION}_2" 2>/dev/null || true
        }

        Before create_another_tmp_runner_file
        After rm_another_tmp_runner_file

        It 'waits until the temporary file is present and checks that the process is alive'
            When call wait_until_tmp_runner_file_exists WaitTest "${TMP_DATA_FILE}_2" $$ 5
            The status should be success
            The stdout should eq "Waiting for WaitTest to create the ${TMP_DATA_FILE_LOCATION}_2 file (5 seconds) ..."
            The variable WaitTest_checked_tmp_runner_file should eq true
            The path "${TMP_DATA_FILE_LOCATION}_2" should not be exist
        End

        It "fails since this file doesn't exist within the indicated timeout"
            When call wait_until_tmp_runner_file_exists TmpFileFailTest "inexistent_file_1947489298497479612" $$ 5
            The status should eq 4
            The stdout should eq "Waiting for TmpFileFailTest to create the ${TMPDIR:-/tmp}/inexistent_file_1947489298497479612 file (5 seconds) ..."
            The stderr should eq "Failed to wait for the existence of the ${TMPDIR:-/tmp}/inexistent_file_1947489298497479612 file. Skipping the check."
            The variable TmpFileFailTest_checked_tmp_runner_file should eq true
        End
    End

    Describe 'Error cases'
        Describe 'Fail with inexistent process'
            Mock get_process_info
                true
            End

            It 'fails since the process has already exited'
                When call wait_until_tmp_runner_file_exists AlreadyExitedFailTest "inexistent_file_1947489298497479612" 999999 5
                The status should eq 3
                The stdout should eq "Waiting for AlreadyExitedFailTest to create the ${TMPDIR:-/tmp}/inexistent_file_1947489298497479612 file (5 seconds) ..."
                The stderr should eq "AlreadyExitedFailTest has already exited. Skipping." 
                The variable AlreadyExitedFailTest_checked_tmp_runner_file should eq true
            End
        End

        Describe 'Incorrect service name'
            Parameters
                "Spaces are not allowed"
                "_UnderscoreAtBeginningIsNotAllowed"
                "Special'CharactersAreNotAllowed'*"
            End

            It 'fails since the service name is badly formatted'
                When call wait_until_tmp_runner_file_exists "$1" "${TMP_DATA_FILE}" 0 0
                The status should eq 2
            End
        End

        Describe 'Incorrect temporary file name'
            Parameters
                "Spaces are not allowed"
                "_UnderscoreAtBeginningIsNotAllowed"
                "Special'CharactersAreNotAllowed'*"
            End

            It 'fails since the temporary file name is badly formatted'
                When call wait_until_tmp_runner_file_exists FailWithInvalidTmpRunnerFilenameTest "$1" 0 0
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
                When call wait_until_tmp_runner_file_exists FailWithInvalidTimeoutTest "${TMP_DATA_FILE}" 0 "$1"
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
                When call wait_until_tmp_runner_file_exists FailWithInvalidPID "${TMP_DATA_FILE}" "$1" 0
                The status should eq 2
            End
        End
    End
End