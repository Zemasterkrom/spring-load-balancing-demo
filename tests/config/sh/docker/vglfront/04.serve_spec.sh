
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
cd ../../../vglfront/server/docker || return 1
load_core_only=true . ./serve.sh

Describe 'Front server handling'
    no_background_process_is_alive() {
        [ -z "$(jobs -p)" ]
    }

    exit_script() {
        return "${1:-0}"
    }
    

    nginx() {
        while true; do sleep 1; done
    }

    wait() {
        kill -2 $! >/dev/null 2>&1 || {
            cleanup $?
            return $?
        }
        cleanup 130
    }

    Context 'Abstract (mocked) behavior'
        Context 'Successful start'
            configure_browser_environment() {
                configured_browser_environment=true
            }

            test() {
                true
            }

            rm() {
                js_environment_file_deleted=true
            }

            BeforeEach load_core_only=false

            It 'handles the front server successfully' 
                When call start
                The status should eq 130
                The stdout should satisfy true
                The stderr should be blank
                The variable configured_browser_environment should eq true
                The variable js_environment_file_deleted should eq true
                Assert no_background_process_is_alive
            End
        End
    End

    Context 'Concrete run without front server start'
        configure_browser_environment() {
            if configure_environment_file "${SHELLSPEC_PROJECT_ROOT}/../../../vglfront/src/assets/environment.js" C.UTF-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = @JSVALUE@;" url "${API_URL:-http://localhost:10000}"; then
                configured_browser_environment=true
            fi
        }

        rm() {
            unlink "${SHELLSPEC_PROJECT_ROOT}/../../../vglfront/src/assets/environment.js" >/dev/null 2>&1
        }

        test() {
            if echo "$@" | grep -q "/usr/share/nginx/html/assets/environment.js"; then
                [ -f "${SHELLSPEC_PROJECT_ROOT}/../../../vglfront/src/assets/environment.js" ]
            else
                sh -c "test $*"
            fi
        }

        BeforeEach load_core_only=false

        It 'handles the front server successfully'
            When call start
            The status should eq 130
            The stdout should satisfy true
            The stderr should be blank
            The variable configured_browser_environment should eq true
            The file "../../src/assets/environment.js" should not be exist
            Assert no_background_process_is_alive
        End
    End
End