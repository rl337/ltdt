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
}



run_all_tests
