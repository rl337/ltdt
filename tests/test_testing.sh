#!/bin/bash

SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/../bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asset_management.sh"
. "$BASH_DIR/testing.sh"


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
