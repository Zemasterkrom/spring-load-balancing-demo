# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Kill process'
    start_process() {
        { sleep 10; } &
        test_PID=$!
    }

    process_is_killed() {
        ps -p ${test_pid:-0} >/dev/null 2>&1
    }

    Describe 'Success cases'
        BeforeEach start_process

        It 'stops an existing process'
            When call kill_process StopExistingProcess ${test_PID} 1 0 true
            The status should be success
            The line 1 of stdout should eq "Stopping StopExistingProcess with PID ${test_PID}"
            The line 2 of stdout should eq "Waiting for StopExistingProcess with PID ${test_PID} to stop (1 seconds) ..."
            The line 3 of stdout should eq "Stopped StopExistingProcess with PID ${test_PID}"
            Assert process_is_killed
        End

        It 'force kills an existing process'
            When call kill_process ForceKillExistingProcess ${test_PID} 0 1 false
            The status should be success
            The line 1 of stdout should eq "Force killing ForceKillExistingProcess with PID ${test_PID}"
            The line 2 of stdout should eq "Waiting for ForceKillExistingProcess with PID ${test_PID} to stop (1 seconds) ..."
            The line 3 of stdout should eq "Force killed ForceKillExistingProcess with PID ${test_PID}"
            Assert process_is_killed
        End
    End

    Describe 'Error cases'
        Describe 'Inexistent process'
            Mock kill
                return 1
            End

            It "fails to stop since the process doesn't exists"
                When call kill_process StopInexistentProcess 1 1 0 true
                The status should eq 10
                The line 1 of stdout should eq "Stopping StopInexistentProcess with PID 1"
                The line 1 of stderr should eq "--> Standard stop failed : force killing StopInexistentProcess with PID 1"
                The line 2 of stderr should eq "Failed to force kill StopInexistentProcess with PID 1"
            End

            It "fails to force kill since the process doesn't exists"
                When call kill_process ForceKillInexistentProcess 1 0 1 false
                The status should eq 16
                The line 1 of stdout should eq "Force killing ForceKillInexistentProcess with PID 1"
                The line 1 of stderr should eq "Failed to force kill ForceKillInexistentProcess with PID 1"
            End
        End

        Describe 'Basic timeout fail'
            kill() {
                true
            }

            Mock wait_for_process_to_stop
                return 1
            End

            It 'fails since a timeout occurs while waiting for the process to stop (stop request)'
                When call kill_process StopProcessTimeout 1 1 0 true
                The status should eq 14
                The line 1 of stdout should eq "Stopping StopProcessTimeout with PID 1"
                The line 1 of stderr should eq "--> Standard stop failed : force killing StopProcessTimeout with PID 1"
                The line 2 of stderr should eq "Failed to wait for StopProcessTimeout with PID 1 to stop"
            End

            It 'fails since a timeout occurs while waiting for the process to stop (force kill request)'
                When call kill_process ForceKillProcessTimeout 1 0 1 false
                The status should eq 17
                The line 1 of stdout should eq "Force killing ForceKillProcessTimeout with PID 1"
                The line 1 of stderr should eq "Failed to wait for ForceKillProcessTimeout with PID 1 to stop"
            End
        End

        Describe 'Standard stop fail'
            kill() {
                if [ "$1" = "-15" ]; then
                    return 1
                fi
            }

            Mock wait_for_process_to_stop
                true
            End

            It 'partially fails because the standard stop failed, but the forced kill worked'
                When call kill_process FirstStopRequestFail 1 1 0 true
                The status should eq 12
                The line 1 of stdout should eq "Stopping FirstStopRequestFail with PID 1"
                The line 2 of stdout should eq "Force killed FirstStopRequestFail with PID 1"
                The line 1 of stderr should eq "--> Standard stop failed : force killing FirstStopRequestFail with PID 1"
            End
        End

        Describe 'Standard stop timeout, force kill success'
            kill() {
                true
            }

            Mock wait_for_process_to_stop
                if [ "$3" = "1" ]; then
                    return 1
                fi
            End

            It 'partially fails because the standard stop timed out, but the forced kill worked'
                When call kill_process StopTimeoutForceKillSuccess 1 1 0 true
                The status should eq 15
                The line 1 of stdout should eq "Stopping StopTimeoutForceKillSuccess with PID 1"
                The line 2 of stdout should eq "Force killed StopTimeoutForceKillSuccess with PID 1"
                The line 1 of stderr should eq "--> Standard stop failed : force killing StopTimeoutForceKillSuccess with PID 1"
            End
        End

        Describe 'Standard stop timeout, force kill fail'
            kill() {
                if [ "$1" = "-9" ]; then
                    return 1
                fi
            }

            Mock wait_for_process_to_stop
                return 1
            End

            It 'fails because the standard stop errored out, and the forced kill too'
                When call kill_process StopFailForceKillFail 1 1 0 true
                The status should eq 13
                The line 1 of stdout should eq "Stopping StopFailForceKillFail with PID 1"
                The line 1 of stderr should eq "--> Standard stop failed : force killing StopFailForceKillFail with PID 1"
                The line 2 of stderr should eq "Failed to force kill StopFailForceKillFail with PID 1"
            End
        End

        Describe 'Standard stop fail, force kill timeout'
            kill() {
                if [ "$1" = "-15" ]; then
                    return 1
                fi
            }

            Mock wait_for_process_to_stop
                return 1
            End

            It 'fails because the standard stop errored out, and the forced kill too'
                When call kill_process StopFailForceKillTimeout 1 1 0 true
                The status should eq 11
                The line 1 of stdout should eq "Stopping StopFailForceKillTimeout with PID 1"
                The line 1 of stderr should eq "--> Standard stop failed : force killing StopFailForceKillTimeout with PID 1"
                The line 2 of stderr should eq "Failed to wait for StopFailForceKillTimeout with PID 1 to stop"
            End
        End
    End
End