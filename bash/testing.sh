if [ "X$_X_TESTING_LIB_" == "X" ]; then
_X_TESTING_LIB_=true

if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asserts.sh"


list_all_tests() {
    declare -f | grep '()' | cut -f 1 -d\  | grep -e '^test_'
}

list_all_setup() {
    declare -f | grep '()' | cut -f 1 -d\  | grep -e '^setup_'
}

list_all_teardown() {
    declare -f | grep '()' | cut -f 1 -d\  | grep -e '^teardown_'
}

setup_00_testdir() {
    if [ "X$TEST_NAME" == "X" ]; then
        LOG_NAME="$0" fatal "Attempted to setup for unset TEST_NAME"
    fi

    TEST_DIR="/tmp/$TEST_NAME-$$"
    if [ -d "$TEST_DIR" ]; then
        LOG_NAME="$TEST_NAME" fatal "Test directory $TEST_DIR already exists"
    fi

    mkdir -p "$TEST_DIR"
    if [ $? -ne 0 ]; then
        LOG_NAME="$TEST_NAME" fatal "Could not create test directory $TEST_DIR"
    fi

    export TEST_DIR
    LOG_NAME="$TEST_NAME" info "Test directory: $TEST_DIR"
}

teardown_99_testdir() {
    if [ "X$TEST_DIR" == "X" ]; then
        LOG_NAME="$TEST_NAME" fatal "Attempted to teardown unset TEST_DIR"
    fi

    if [ "X$TEST_DIR" == "X/" ]; then
        LOG_NAME="$TEST_NAME" fatal "Attempted to teardown bad directory /"
    fi

    if [ "X$TEST_DIR" == "X/tmp" ]; then
        LOG_NAME="$TEST_NAME" fatal "Attempted to teardown bad directory /tmp"
    fi
    
    if [ ! -d "$TEST_DIR" ]; then
        LOG_NAME="$TEST_NAME" fatal "Test directory $TEST_DIR already exists"
    fi

    rm -rf "$TEST_DIR"
    if [ $? -ne 0 ]; then
        LOG_NAME="$TEST_NAME" fatal "Could not remove test dir $TEST_DIR"
    fi
}

run_all_tests() {

    _X_TESTS=$(list_all_tests)
    _X_SETUPS=$(list_all_setup)
    _X_TEARDOWNS=$(list_all_teardown)
    _X_RAN=0
    _X_PASSED=0
    _X_FAILED=0
    for TEST_NAME in $_X_TESTS; do

        _X_TEST_RESULT=0
        _X_TEST_OUTPUT="$(
            LOG_NAME="$TEST_NAME"
            for _X_SETUP in $_X_SETUPS; do
                $_X_SETUP 2>&1
                if [ $? -ne 0 ]; then
                    fatal "$_X_SETUP exited abnormally"
                fi
            done
            $TEST_NAME 2>&1
            if [ $? -ne 0 ]; then
                fatal "$TEST_NAME exited abnormally"
            fi
            for _X_TEARDOWN in $_X_TEARDOWNS; do
                $_X_TEARDOWN 2>&1
                if [ $? -ne 0 ]; then
                    fatal "$_X_TEARDOWN exited abnormally"
                fi
            done
        )"
        if [ $? -ne 0 ]; then
            _X_FAILED=$(expr $_X_FAILED + 1)
            _X_TEST_RESULT=1
        else
            _X_PASSED=$(expr $_X_PASSED + 1)
        fi

        if [ $_X_TEST_RESULT -ne 0 ]; then
            LOG_NAME="$TEST_NAME" info "TEST_OUTPUT: $_X_TEST_OUTPUT"
        fi
        _X_RAN=$(expr $_X_RAN + 1)
    done

    LOG_NAME=$0 info "test file: $0 passed $_X_PASSED/$_X_RAN ($_X_FAILED failures)"
    return $_X_FAILED
}

fi
