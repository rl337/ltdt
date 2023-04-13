#!/bin/bash

SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/../bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asset_management.sh"
. "$BASH_DIR/asserts.sh"
. "$BASH_DIR/testing.sh"


setup_environment() {
    TEST_SET_ENVIRONMENT="omg this works"

    export TEST_SET_ENVIRONMENT
}

test_setup() {
    if [ "X$TEST_SET_ENVIRONMENT" == "X" ]; then
        fatal "setup should have set TEST_SET_ENVIRONMENT"
    fi

    if [ "X$TEST_SET_ENVIRONMENT" != "Xomg this works" ]; then
        fatal "setup should have set TEST_SET_ENVIRONMENT to 'omg this works'"
    fi
}

test_assert_defined() {
    XYZ_ABC_1=defined
    assert_defined XYZ_ABC_1 "XYZ_ABC_1 was JUST defined!"

    (assert_defined XYZ_ABC_2 "XYZ_ABC_2 was actually NOT defined")
    if [ $? -eq 0 ]; then
        fatal "assert_defined should have failed for XYZ_ABC_2"
    fi

}

test_assert_equal() {
    assert_equal "omg" "omg"
    X=$(assert_equal "not" "equal")
    if [ $? == 0 ]; then
        fatal "should have failed"
    fi
}

test_assert_zero() {
    assert_zero 0
    X=$(assert_zero 1)
    if [ $? == 0 ]; then
        fatal "should have failed"
    fi
}
test_assert_not_zero() {
    assert_not_zero 1
    X=$(assert_not_zero 0)
    if [ $? == 0 ]; then
        fatal "should have failed"
    fi
}


run_all_tests
