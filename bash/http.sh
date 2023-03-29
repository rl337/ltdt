if [ "X$_X_HTTP_LIB_" == "X" ]; then
_X_HTTP_LIB_=true

if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asset_management.sh"

CURL_EXE=curl


HTTP_GET_CALLS=0
http_reset_get_calls() {
    HTTP_GET_CALLS=0
}

http_increment_get_calls() {
    HTTP_GET_CALLS=$(expr 1 + $HTTP_GET_CALLS)
}

assert_http_testing() {
    if [ "X$HTTP_TESTING" == "X" ]; then
        fatal "Expected HTTP_TESTING environment variable to be set. http_expect calls disabled"
    fi
}

# $1 = call number since last http_reset_get_calls
# $2 = URL
# $3 = get param json_dict
# $4 = http headers json_dict
# $5 = response string
http_expect_get() {
    assert_http_testing

    assert_valid_integer "$1"
    export "_X_EXPECT_GET_$1"="$( jq -n \
        --arg url "$2" \
        --arg params "$3" \
        --arg headers "$4" \
        --arg response "$5" \
        '{url: $url, headers: $headers, params: $params, response: $response}'
    )"
}

# This function should take the same params as http_get
# $1 = URL
# $2 = get param json_dict
# $3 = http headers json_dict
http_test_get() {
    assert_http_testing

    _X_EXPECT_ENV="_X_EXPECT_GET_$HTTP_GET_CALLS"
    _X_CALL_INFO=$(echo "${!_X_EXPECT_ENV}")
    if [ $? -ne 0 ]; then
        fatal "Could not find expectation for http get call $HTTP_GET_CALLS"
    fi
    if [ "X$_X_CALL_INFO" == "X" ]; then
        fatal "Empty expectation set for http get call $HTTP_GET_CALLS"
    fi

    _X_EXPECTED_URL="$(echo "$_X_CALL_INFO" | jq --raw-output '.url')"
    if [ "X$_X_EXPECTED_URL" != "X$1" ]; then
        fatal "Expected URL $_X_EXPECTED_URL but found $1"
    fi

    _X_EXPECTED_PARAMS="$(echo "$_X_CALL_INFO" | jq --raw-output '.params')"
    if [ "X$_X_EXPECTED_PARAMS" != "X$2" ]; then
        fatal "Expected URL $_X_EXPECTED_PARAMS but found $2"
    fi

    _X_EXPECTED_HEADERS="$(echo "$_X_CALL_INFO" | jq --raw-output '.headers')"
    if [ "X$_X_EXPECTED_HEADERS" != "X$3" ]; then
        fatal "Expected URL $_X_EXPECTED_HEADERS but found $3"
    fi
    
    echo "$_X_CALL_INFO" | jq --raw-output '.response'
    if [ $? -ne 0 ]; then
        fatal "Could not extract response from $_X_CALL_INFO"
    fi

    http_increment_get_calls
}

# $1 json dictionary to convert into query_string
http_json_dict_to_query_string() {
    echo "$1" | jq -r 'to_entries | map("\(.key)=\(.value|@uri)") | join("&")'
}

http_json_dict_to_header_params() {
    _X_HEADERS=$(echo $1 | jq -r 'to_entries | map("\(.key): \(.value|tostring)" | @sh) | join(" -H ")')
    if [ $? -ne 0 ]; then
        fatal "Could not parse headers from $1"
    fi

    if [ "X$_X_HEADERS" == "X" ]; then
        return 0
    fi

    echo "-H $_X_HEADERS"
}

# $1 = URL
# $2 = get param json_dict
# $3 = http headers json_dict
http_get() {
    http_increment_get_calls

    _X_HEADERS=$(http_json_dict_to_header_params "$3")
    if [ $? -ne 0 ]; then
        fatal "Could not create header params from $3"
    fi

    _X_QUERY_STRING=$(http_json_dict_to_query_string "$2")
    if [ $? -ne 0 ]; then
        fatal "Could not create query string from $2"
    fi
    
    _X_FULL_URL="$1"
    if [ "X$_X_QUERY_STRING" != "X" ]; then
        _X_FULL_URL="$_X_FULL_URL?$_X_QUERY_STRING"
    fi

    "$CURL_EXE" -s $_X_HEADERS "$_X_FULL_URL" 
    if [ $? -ne 0 ]; then
        fatal "Could not curl $_X_FULL_URL with headers $3"
    fi
}

fi
