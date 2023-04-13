#!/bin/bash

SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/../bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/http.sh"
. "$BASH_DIR/testing.sh"

setup_http_test_env() {
    export HTTP_TESTING=1
}

test_http_get() {
    HTTP_TESTING=""
    TEST_RAW=$(CURL_EXE=echo http_get http://example.com '{"a": 1, "b": "foo & bar"}' '{"Awesomeness": "maximum"}')
    assert_string_match "$TEST_RAW" "^-s"
    assert_string_match "$TEST_RAW" "-H 'Awesomeness: maximum'"
    assert_string_match "$TEST_RAW" "http://example.com?a=1&b=foo%20%26%20bar"
}

test_http_post_echo() {
    HTTP_TESTING=""
    VALUE=maximum
    TEST_PARAMS=$(jq -n -S -c --raw-output \
        --arg api_key "Bearer $VALUE" \
        '{"Content-Type": "application/json", "Authorization": $api_key}' \
    )
    TEST_RAW=$(CURL_EXE=echo http_post \
        http://example.com \
        '{"a": 1, "b": "foo & bar"}' \
        "$TEST_PARAMS" \
    )
    assert_string_match "$TEST_RAW" "^-s"
    assert_string_match "$TEST_RAW" "-H Authorization: Bearer maximum" # unfortunately echo strips the ''"
    assert_string_match "$TEST_RAW" "http://example.com"
}

test_http_test_single_get() {
    EXPECTED_RESPONSE="omg this is it"
    http_expect_get "http://example.com/a/b" '{"a":1}' '{"Awesome":"true"}' "$EXPECTED_RESPONSE"

    ACTUAL_RESPONSE=$(http_get http://example.com/a/b '{"a":1}' '{"Awesome":"true"}')
    assert_equal "$EXPECTED_RESPONSE" "$ACTUAL_RESPONSE" "Call response didn't match expected"
}

test_http_test_multiple_get() {
    EXPECTED_RESPONSE_0="omg this is it"
    EXPECTED_PARAMS_0='{"a":1}'
    EXPECTED_HEADERS_0='{"Awesome":"true"}'
    EXPECTED_URL_0='http://example.com/call/0'
    http_expect_get "$EXPECTED_URL_0" "$EXPECTED_PARAMS_0" "$EXPECTED_HEADERS_0" "$EXPECTED_RESPONSE_0"

    EXPECTED_RESPONSE_1="omg that is it"
    EXPECTED_PARAMS_1='{"a":2}'
    EXPECTED_HEADERS_1='{"Awesome":"false"}'
    EXPECTED_URL_1='http://example.com/call/1'
    http_expect_get "$EXPECTED_URL_1" "$EXPECTED_PARAMS_1" "$EXPECTED_HEADERS_1" "$EXPECTED_RESPONSE_1"

    ACTUAL_RESPONSE_0=$(http_get "$EXPECTED_URL_0" "$EXPECTED_PARAMS_0" "$EXPECTED_HEADERS_0")
    assert_equal "$EXPECTED_RESPONSE_0" "$ACTUAL_RESPONSE_0" "Call 0 responses didn't match"

    ACTUAL_RESPONSE_1=$(http_get "$EXPECTED_URL_1" "$EXPECTED_PARAMS_1" "$EXPECTED_HEADERS_1")
    assert_equal "$EXPECTED_RESPONSE_1" "$ACTUAL_RESPONSE_1" "Call 1 responses didn't match"
}

test_http_test_single_post() {
    EXPECTED_RESPONSE="omg this is it"
    http_expect_post "http://example.com/a/b" '{"x":1}' '{"Awesome":"true"}' "$EXPECTED_RESPONSE"

    ACTUAL_RESPONSE=$(http_post http://example.com/a/b '{"x":1}' '{"Awesome":"true"}')
    assert_equal "$EXPECTED_RESPONSE" "$ACTUAL_RESPONSE" "Call response didn't match expected"
}

run_all_tests "$@"
