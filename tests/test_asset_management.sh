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

test_assert_valid_asset_root() {
    ASSET_ROOT=/tmp
    assert_valid_asset_root

    ASSET_ROOT=.
    assert_valid_asset_root

    ASSET_ROOT=""
    $(assert_valid_asset_root)
    assert_not_zero $? "empty asset root is not valid"

    ASSET_ROOT="/a/b/c/d/e/f/g"
    $(assert_valid_asset_root)
    assert_not_zero $? "invalid path is not a valid asset root"
}

test_root_asset() {
    ACTUAL=$(root_asset)
    assert_equal "story" "$ACTUAL"

    ROOT_ASSET="omg"
    ACTUAL=$(root_asset)
    assert_equal "omg" "$ACTUAL"
}

test_sub_asset() {
    ROOT_ASSET="omg"
    assert_equal "omg/suffix" $(sub_asset $(root_asset) "suffix")
}

test_suffix_asset() {
    ROOT_ASSET="omg"
    assert_equal "omg_suffix" $(suffix_asset $(root_asset) "suffix")
}

test_parent_asset() {
    ROOT_ASSET="omg"
    CHILD_ASSET=$(sub_asset $(root_asset) "child")
    GRANDCHILD_ASSET=$(sub_asset "$CHILD_ASSET" "grandchild")
    assert_equal "omg/child/grandchild" "$GRANDCHILD_ASSET"
    assert_equal "omg/child" $(parent_asset "$GRANDCHILD_ASSET")
    assert_equal "omg" $(parent_asset $(parent_asset "$GRANDCHILD_ASSET"))

    $(parent_asset $(parent_asset $(parent_asset "$GRANDCHILD_ASSET")))
    assert_not_zero $? "should not be able to get parent of root asset"
}

test_asset_path() {
    ASSET_ROOT=/tmp
    
    assert_equal "/tmp/abc" $(asset_path "abc")
    assert_equal "/tmp/abc_prompt.prompt" $(asset_path "abc_prompt")
    assert_equal "/tmp/abc_context.context" $(asset_path "abc_context")
    assert_equal "/tmp/abc_response.json" $(asset_path "abc_response")
    assert_equal "/tmp/abc_portrait.jpg" $(asset_path "abc_portrait")
    assert_equal "/tmp/abc_image.jpg" $(asset_path "abc_image")
    assert_equal "/tmp/abc_skybox.jpg" $(asset_path "abc_skybox")
    assert_equal "/tmp/abc_list.csv" $(asset_path "abc_list")
    assert_equal "/tmp/abc_base64.base64" $(asset_path "abc_base64")
}

test_file_exists() {
    ASSET_ROOT=/tmp
    ROOT_ASSET="test_$$"

    ROOT_ASSET_PATH=$(asset_path $ROOT_ASSET)
    file_exists $ROOT_ASSET
    assert_not_zero $? "$ROOT_ASSET_PATH shouldn't exist initially"

    touch "$ROOT_ASSET_PATH"
    file_exists "$ROOT_ASSET"
    assert_zero $? "$ROOT_ASSET_PATH should now exist"

    rm "$ROOT_ASSET_PATH"
    assert_zero $? "$ROOT_ASSET_PATH should be deletable"
}

test_directory_exists() {
    ASSET_ROOT=/tmp
    ROOT_ASSET="test_$$"

    ROOT_ASSET_PATH=$(asset_path $ROOT_ASSET)
    directory_exists $ROOT_ASSET
    assert_not_zero $? "$ROOT_ASSET_PATH shouldn't exist initially"

    mkdir "$ROOT_ASSET_PATH"
    directory_exists "$ROOT_ASSET"
    assert_zero $? "$ROOT_ASSET_PATH should now exist"

    rmdir "$ROOT_ASSET_PATH"
    assert_zero $? "$ROOT_ASSET_PATH should be deletable"
}

test_assert_file_exists() {
    ASSET_ROOT=/tmp
    ROOT_ASSET="test_$$"

    ROOT_ASSET_PATH=$(asset_path $ROOT_ASSET)
    $(assert_file_exists $ROOT_ASSET)
    assert_not_zero $? "$ROOT_ASSET_PATH shouldn't exist initially"

    touch "$ROOT_ASSET_PATH"
    assert_file_exists "$ROOT_ASSET"
    assert_zero $? "$ROOT_ASSET_PATH should now exist"

    rm "$ROOT_ASSET_PATH"
    assert_zero $? "$ROOT_ASSET_PATH should be deletable"
}

test_assert_directory_exists() {
    ASSET_ROOT=/tmp
    ROOT_ASSET="test_$$"

    ROOT_ASSET_PATH=$(asset_path $ROOT_ASSET)
    $(directory_exists $ROOT_ASSET)
    assert_not_zero $? "$ROOT_ASSET_PATH shouldn't exist initially"

    mkdir "$ROOT_ASSET_PATH"
    assert_directory_exists "$ROOT_ASSET"
    assert_zero $? "$ROOT_ASSET_PATH should now exist"

    rmdir "$ROOT_ASSET_PATH"
    assert_zero $? "$ROOT_ASSET_PATH should be deletable"
}

run_all_tests
