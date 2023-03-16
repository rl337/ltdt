if [ "X$_X_TESTING_LIB_" == "X" ]; then
_X_TESTING_LIB_=true


list_all_tests() {
    declare -f | grep '()' | cut -f 1 -d\  | grep -e '^test_'
}

run_all_tests() {

    _X_TESTS=$(list_all_tests)
    _X_RAN=0
    _X_PASSED=0
    _X_FAILED=0
    for _X_TEST_ in $_X_TESTS; do
        _X_OUTPUT=$(
            $_X_TEST_ 2>&1
        )
        if [ $? -ne 0 ]; then
            info "$_X_TEST_: $_X_OUTPUT"
            _X_FAILED=$(expr $_X_FAILED + 1)
        else
            _X_PASSED=$(expr $_X_PASSED + 1)
        fi
        _X_RAN=$(expr $_X_RAN + 1)
    done

    info "test file: $0 passed $_X_PASSED/$_X_RAN ($_X_FAILED failures)"
}

# $1 = param 1
# $2 = param 2
# $3 = message
# fatal unles $1 == $2
assert_equal() {
    if [ "X$1" != "X$2" ]; then
        fatal "assert $1 == $2: $3"
    fi
}

fi
