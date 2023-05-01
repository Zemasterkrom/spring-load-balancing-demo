# shellcheck shell=sh

# Defining variables and functions here will affect all specfiles.
# Change shell options inside a function may cause different behavior,
# so it is better to set them here.
# set -eu

# This callback function will be invoked only once before loading specfiles.
spec_helper_precheck() {
  # Available functions: info, warn, error, abort, setenv, unsetenv
  # Available variables: VERSION, SHELL_TYPE, SHELL_VERSION
  : minimum_version "0.28.1"
}

# This callback function will be invoked after a specfile has been loaded.
spec_helper_loaded() {
  :
}

# This callback function will be invoked after core modules has been loaded.
spec_helper_configure() {
  # Available functions: import, before_each, after_each, before_all, after_all
  : import 'custom_matcher'
  cd ../../..
  source_only=true context_dir="$(pwd)" . ./run.sh

  while TMP_DATA_FILE="shellspec_slb_$(random_number 9999999)" && [ -f "${TMPDIR:-/tmp}/${TMP_DATA_FILE}" ]; do
    true
  done

  before_all "create_tmp_data_file"
  after_all "rm_tmp_data_file"
}

create_tmp_data_file() {
  set -o noclobber

  while TMP_DATA_FILE="shellspec_slb_$(random_number 9999999)" && [ -f "${TMPDIR:-/tmp}/${TMP_DATA_FILE}" ]; do
    true
  done

  if >"${TMPDIR:-/tmp}/${TMP_DATA_FILE}" 2>/dev/null; then
    export TMP_DATA_FILE
    export TMP_DATA_FILE_LOCATION="${TMPDIR:-/tmp}/${TMP_DATA_FILE}"
  else
    create_tmp_data_file
  fi

  set +o noclobber
}

rm_tmp_data_file() {
  rm "${TMP_DATA_FILE_LOCATION}" 2>/dev/null || true
}
