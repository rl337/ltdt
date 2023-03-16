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


test_assert_valid_asset() {
    assert_valid_asset "omg"
    assert_valid_asset "omg/haha/lol"
    assert_valid_asset "asset/has_suffix"
    assert_valid_asset "asset/has_suffix/ends_with_number0"

    $(assert_valid_asset "/omg")
    assert_not_zero $? "assets shouldn't start with /"

    $(assert_valid_asset ".omg")
    assert_not_zero $? "assets shouldn't start with ."

    $(assert_valid_asset "1omg")
    assert_not_zero $? "assets shouldn't start with numbers"

    $(assert_valid_asset "omg/")
    assert_not_zero $? "assets shouldn't end with /"

    $(assert_valid_asset "omg.")
    assert_not_zero $? "assets shouldn't end with ."

}

test_assert_valid_integer() {
    assert_valid_integer "1"
    assert_valid_integer 1000
    assert_valid_integer 0

    $(assert_valid_integer "omg")
    assert_not_zero $? "omg is not an integer"
    $(assert_valid_integer "1.23")
    assert_not_zero $? "string 1.23 is not an integer"
    $(assert_valid_integer 1.23)
    assert_not_zero $? "number 1.23 is not an integer"
}

run_all_tests
