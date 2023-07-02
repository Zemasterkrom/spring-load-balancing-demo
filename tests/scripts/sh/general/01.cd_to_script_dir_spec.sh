# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
Describe 'Change current directory to script directory'
    Context 'Success cases'
        cd() {
            echo "ScriptRoot"
        }

        dirname() {
            true
        }

        test() {
            true
        }

        Context 'Set without location hint'
            BeforeEach context_dir=

            Context 'With shell path detection ability'
                pwd() {
                    if [ -z "$1" ]; then
                        echo "ScriptRoot"
                    fi
                }

                test_shell_path_detection_ability() {
                    true
                }

                It 'sets and changes the root location of the script by detecting the script root path'
                    When call cd_to_script_dir
                    The variable cd_dir should eq ScriptRoot
                    The variable script_directory should eq ScriptRoot
                    The variable changed_to_base_dir should eq true
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                End
            End

            Context 'Without shell path detection ability'
                pwd() {
                    if [ -z "$1" ]; then
                        echo "ScriptRoot"
                    fi
                }

                test_shell_path_detection_ability() {
                    false
                }

                It 'does nothing and succeeds since the current directory contains the base script file'
                    When call cd_to_script_dir
                    The variable cd_dir should be blank
                    The variable script_directory should eq ScriptRoot
                    The variable changed_to_base_dir should eq true
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                End
            End
        End

        Context 'Set with location hint'
            pwd() {
                echo "OtherPath"
            }

            BeforeEach context_dir="OtherPath"

            It 'sets and changes the root location of the script using the custom context_dir variable'
                When call cd_to_script_dir
                The variable cd_dir should eq OtherPath
                The variable script_directory should eq OtherPath
                The variable changed_to_base_dir should eq true
                The status should be success
                The stdout should be blank
                The stderr should be blank
            End
        End

        Context 'Change to script directory if not already in the script directory'
            pwd() {
                echo "OtherPath"
            }

            cd() {
                cd_location="$1"
            }

            BeforeEach 'changed_to_base_dir=true && script_directory="ScriptRoot"'

            It 'changes location to the script directory'
                When call cd_to_script_dir
                The variable cd_dir should be blank
                The variable script_directory should eq ScriptRoot
                The variable changed_to_base_dir should eq true
                The variable cd_location should eq ScriptRoot
                The status should be success
                The stdout should be blank
                The stderr should be blank
            End
        End
    End

    Context 'Error cases'
        Context 'Set with a non-existent location path hint'
            test() {
                false
            }

            BeforeEach context_dir="OtherPath"

            It 'tries to change the current location using the custom context_dir variable representing a non-existent location'
                When call cd_to_script_dir
                The variable cd_dir should eq OtherPath
                The variable script_directory should be blank
                The variable changed_to_base_dir should eq false
                The status should eq 126
                The stdout should be blank
                The stderr should eq "OtherPath is not a directory. Unable to continue."
            End
        End

        Context 'Location change error'
            test() {
                true
            }

            cd() {
                false
            }

            BeforeEach context_dir="OtherPath"

            It 'tries to change the current location but fails because of a system error'
                When call cd_to_script_dir
                The variable cd_dir should eq OtherPath
                The variable script_directory should be blank
                The variable changed_to_base_dir should eq false
                The status should eq 126
                The stdout should be blank
                The stderr should eq "Unable to switch to the OtherPath base directory of the script. Unable to continue."
            End
        End

        Context 'Location change error using the cached script directory'
            pwd() {
                echo "OtherPath"
            }

            cd() {
                false
            }

            BeforeEach 'changed_to_base_dir=true && script_directory="ScriptRoot"'

            It 'fails when trying to change the location using the script directory'
                When call cd_to_script_dir
                The variable cd_dir should be blank
                The variable script_directory should eq ScriptRoot
                The variable changed_to_base_dir should eq true
                The status should eq 126
                The stdout should be blank
                The stderr should eq "Unable to switch to the ScriptRoot base directory of the script. Unable to continue."
            End
        End
        
        Context 'Successful resolution of location path, but script file not found'
            test() {
                [ "$1" = "-d" ]
            }

            cd() {
                true
            }

            BeforeEach context_dir="OtherPath"

            It 'changes the current location using the custom location variable context_dir, but fails because the script file cannot be found'
                When call cd_to_script_dir
                The variable cd_dir should eq OtherPath
                The variable script_directory should be blank
                The variable changed_to_base_dir should eq false
                The status should eq 127
                The stdout should be blank
                The stderr should eq "Unable to find the base script in the changed OtherPath directory. Unable to continue."
            End
        End 
    End
End