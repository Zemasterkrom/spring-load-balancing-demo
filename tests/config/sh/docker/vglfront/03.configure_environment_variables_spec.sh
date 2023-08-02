# shellcheck shell=sh
# shellcheck disable=SC1090
# shellcheck disable=SC1091
# shellcheck disable=SC2034
# shellcheck disable=SC2120
# shellcheck disable=SC2154
# shellcheck disable=SC2215
# shellcheck disable=SC2286
# shellcheck disable=SC2288
# shellcheck disable=SC2317
cd ../../../ldfront/server/docker || return 1
load_core_only=true . ./serve.sh

Describe 'Front server environment configuration'
    Context 'Environment variables configurator'
        BeforeEach 'if [ -f test.js ]; then rm test.js; fi'
        AfterEach 'if [ -f test.js ]; then rm test.js; fi'

        Context 'Success cases'
            Context 'Single variable'
                Parameters
                    key value
                    key
                End

                It "writes a single browser environment variable to a file using JavaScript notation : $1 = $2"
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" "$1" "$2"
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The contents of file test.js should eq "window['environment']['$1'] = '$2';"
                End
            End

            Context 'Multiple variables'
                Parameters
                    keyOne valueTwo keyTwo valueTwo
                    keyOne "" keyTwo valueTwo
                    keyOne valueOne keyTwo ""
                    keyOne "" keyTwo ""
                End

                It "writes two browser environment variables to a file using JavaScript notation : $1 = $2 ; $3 = $4"
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" "$1" "$2" "$3" "$4"
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The lines of contents of file test.js should eq 2
                    The line 1 of contents of file test.js should eq "window['environment']['$1'] = '$2';"
                    The line 2 of contents of file test.js should eq "window['environment']['$3'] = '$4';"
                End
            End

            Context 'Omitted value for a key'
                It "writes an empty value browser environment variable value to a file using JavaScript notation"
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" key
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The lines of contents of file test.js should eq 1
                    The line 1 of contents of file test.js should eq "window['environment']['key'] = '';"
                End

                It "writes two browser environment variables and a empty variable value to a file using JavaScript notation"
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" keyOne valueOne keyTwo
                    The status should be success
                    The stdout should be blank
                    The stderr should be blank
                    The lines of contents of file test.js should eq 2
                    The line 1 of contents of file test.js should eq "window['environment']['keyOne'] = 'valueOne';"
                    The line 2 of contents of file test.js should eq "window['environment']['keyTwo'] = '';"
                End
            End
        End

        Context 'Error cases'
            Context 'Invalid number of arguments'
                It 'fails to configure a JavaScript environment file because no arguments have been passed to the script'
                    When call configure_environment_file
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "Usage: configure_environment_file <Path to the environment file> <Environment file encoding> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ..."
                    The file test.js should not be exist
                End

                It 'fails to configure a JavaScript environment file because there is only one argument instead of 6'
                    When call configure_environment_file test.js
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "Usage: configure_environment_file <Path to the environment file> <Environment file encoding> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ..."
                    The file test.js should not be exist
                End

                It 'fails to configure a JavaScript environment file because there are only 2 arguments instead of 6'
                    When call configure_environment_file test.js C.UTF-8
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "Usage: configure_environment_file <Path to the environment file> <Environment file encoding> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ..."
                    The file test.js should not be exist
                End

                It 'fails to configure a JavaScript environment file because there are only 3 arguments instead of 6'
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "Usage: configure_environment_file <Path to the environment file> <Environment file encoding> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ..."
                    The file test.js should not be exist
                End

                It 'fails to configure a JavaScript environment file because there are only 4 arguments instead of 6'
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "Usage: configure_environment_file <Path to the environment file> <Environment file encoding> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ..."
                    The file test.js should not be exist
                End

                It 'fails to configure a JavaScript environment file because there are only 5 arguments instead of 6'
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';"
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "Usage: configure_environment_file <Path to the environment file> <Environment file encoding> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ..."
                    The file test.js should not be exist
                End
            End

            Context 'Invalid configuration'
                Parameters
                    "" C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" key value "The environment file path can't be empty"
                    " " C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" key value "The environment file path can't be empty"
                    test.js C.UTF-8 "" @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" key value "The key placeholder can't be empty"
                    test.js C.UTF-8 " " @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" key value "The key placeholder can't be empty"
                    test.js C.UTF-8 @JSKEY@ "" "window['environment']['@JSKEY@'] = '@JSVALUE@';" key value "The value placeholder can't be empty"
                    test.js C.UTF-8 @JSKEY@ " " "window['environment']['@JSKEY@'] = '@JSVALUE@';" key value "The value placeholder can't be empty"
                    test.js C.UTF-8 @JSKEY@ @JSVALUE@ "" key value "The environment template can't be empty"
                    test.js C.UTF-8 @JSKEY@ @JSVALUE@ " " key value "The environment template can't be empty"
                End

                It "fails to configure a JavaScript environment file because the configuration arguments are invalid : $1 $2 $3 $4 $5"
                    When call configure_environment_file "$1" "$2" "$3" "$4" "$5" "$6" "$7"
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "$8"
                    The file test.js should not be exist
                End
            End
            
            Context 'Data errors'
                It 'fails to configure a JavaScript environment file because the environment variable key is empty'
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" "" value
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "Keys can't be empty. Concerned value : value"
                    The file test.js should not be exist
                End

                It 'fails to configure a JavaScript environment file because an environment variable key is empty'
                    When call configure_environment_file test.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" keyOne valueOne "" valueTwo
                    The status should eq 2
                    The stdout should be blank
                    The stderr should eq "Keys can't be empty. Concerned value : valueTwo"
                    The file test.js should not be exist
                End
            End

            Context 'File errors'
                Context 'Referenced file is a directory'
                    BeforeEach 'if [ -e test.dir ]; then rm -r test.dir; fi && mkdir test.dir'
                    AfterEach 'if [ -e test.dir ]; then rm -r test.dir; fi'

                    It 'fails to configure a JavaScript environment file because the referenced file is a directory'
                        When call node ../FileEnvironmentConfigurator.js test.dir utf-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" key value
                        The status should eq 71
                        The stdout should be blank
                        The stderr should eq "File test.dir is a directory"
                    End
                End

                Context 'Referenced file is not writable'
                    BeforeEach 'if [ -e test.file ]; then chattr -r test.file; rm -r test.file; fi && touch test.file && chattr +r test.file'
                    AfterEach 'if [ -e test.file ]; then chattr -r test.file; rm -r test.file; fi'

                    It 'fails to configure a JavaScript environment file because the referenced file is not writable'
                        When call node ../FileEnvironmentConfigurator.js test.file utf-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" key value
                        The status should eq 71
                        The stdout should be blank
                        The stderr should eq "Can't write to test.file"
                    End
                End
            End
        End
    End

    Context 'Front server environment variables setup'
        configure_browser_environment() {
            configure_environment_file ../../src/assets/environment.js C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = @JSVALUE@;" url "${API_URL:-http://localhost:10000}"
        }

        AfterEach 'rm ../../src/assets/environment.js'

        It 'configures the browser and system related environment variables'
            When call configure_browser_environment
            The status should be success
            The stdout should be blank
            The stderr should be blank
            The file "../../src/assets/environment.js" should be exist
        End
    End
End