# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Register process info'
    reset_processes_data() {
        processes=""
        echo "" > "${TMP_DATA_FILE_LOCATION}"
    }
    restore_processes_data() {
        processes="$(cat "${TMP_DATA_FILE_LOCATION}")"
    }
    save_processes_data() {
        %puts "$(get_registered_processes_info)" > "${TMP_DATA_FILE_LOCATION}"
    }
    BeforeEach restore_processes_data
    AfterEach save_processes_data

    current_process_info_is_correct() {
        [ "$(get_registered_process_info "$1")" = "$2" ]
    }

    retrieved_processes_are_correctly_numbered() {
        [ "$(get_registered_processes_info | wc -l)" = "$1" ]
    }

    Context 'Add process info'
        Context 'Success cases'
            Parameters
                1 TestWithPidOnly 1
                2 TestWithStopCommandOnly "" "true"
                3 TestWithKillCommandOnly "" "" "true"
                4 TestWithStopAndKillCommands "" "" "true" "true"
                5 TestWithPidAndCheckCommand 1 "" "" "" "true"
                6 TestWithStopCommandAndCheckCommand "" "true" "" "true"
                7 TestWithStopKillCheckCommands "" "true" "true" "true"
                8 TestWithGroupMode "" "true" "" "" "true"
                9 TestWithoutGroupMode "" "true" "" "" "false"
                10 TestWithTmpRunnerFile "" "true" "" "" "" "aZ-test_123.test"
                11 TestWithGroupAndTmpRunnerFile "" "true" "" "" "true" "aZ-test_123.test"
                12 TestWithoutGroupAndTmpRunnerFile "" "true" "" "" "false" "aZ-test_123.test"
                13 TestWithAll "1" "true" "true" "true" "false" "aZ-test_123.test"
                14 TestWithAllExceptStartTime "1" "true" "true" "true" "false" "aZ-test_123.test"
                15 TestWithAllExceptStartTimeCheckCommand "1" "true" "true" "" "false" "aZ-test_123.test"
                16 TestWithAllExceptStartTimeCheckKillCommand "1" "true" "" "" "false" "aZ-test_123.test"
                17 TestWithAllExceptStartTimeCheckKillStopCommand "1" "" "" "" "false" "aZ-test_123.test"
            End

            AfterAll reset_processes_data

            It 'adds valid process info'
                When call register_process_info "$2" "$3" "$4" "$5" "$6" "$7" "$8"
                The status should be success
                The lines of variable processes should eq "$1"
                Assert retrieved_processes_are_correctly_numbered "$1"
                Assert current_process_info_is_correct "$2" "$2#$3#$4#$5#$6#$7#$8"
            End
        End

        Context 'Error cases'
            Parameters
                "#"
                "Spaces are not allowed"
                TestWithEmptyPid ""
                TestWithWhitespacePid " "
                TestWithInvalidPid "-1"
                TestWithMalformedPid "PID"
                TestWithMalformedSpacedPid "PID "
                TestWithMalformedStopCommand "1" "#"
                TestWithMalformedKillCommand "1" "" "#"
                TestWithoutRequiredStopOrKillCommandOne "" "" ""
                TestWithMalformedCheckCommand "1" "" "" "#"
                TestWithInvalidBooleanForGroupParam "1" "" "" "" "notaboolean"
                TestWithInvalidTmpRunnerFile "1" "" "" "" "" "#"
            End

            AfterAll reset_processes_data

            It 'disallows invalid process info data'
                When call register_process_info "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8"
                The status should eq 2
                The lines of variable processes should eq 0
                Assert retrieved_processes_are_correctly_numbered 1
                The result of function get_registered_processes_info should be blank
            End
        End
    End

    Context 'Update process info'
        Parameters
            1 Test 1
            2 Test2 2
            3 Test3 "" "true" "true" "true"
            4 Test4 4 "true" "true" "true" "true" "true"
            4 Test2 2 "true" "true" "true" "true" "true"
            4 Test2 2 "" "" "" "true" "true"
            4 Test 1 "true"
            4 Test3 3 "true" "true" "true"
            5 Test5 5
        End

        It 'updates the process data'
            When call register_process_info "$2" "$3" "$4" "$5" "$6" "$7" "$8"
            The status should be success
            The lines of variable processes should eq "$1"
            Assert retrieved_processes_are_correctly_numbered "$1"
            Assert current_process_info_is_correct "$2" "$2#$3#$4#$5#$6#$7#$8"
        End
    End
End