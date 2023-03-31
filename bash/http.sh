if [ "X$_X_HTTP_LIB_" == "X" ]; then
_X_HTTP_LIB_=true

if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asserts.sh"
. "$BASH_DIR/asset_management.sh"

CURL_EXE=curl
_X_EXPECT_HTTP_GET="{}"
_X_EXPECT_HTTP_POST="{}"

is_http_testing() {
    [ "X$HTTP_TESTING" != "X" ]
}

assert_http_testing() {
    is_http_testing
    assert_zero $? "Expected HTTP_TESTING environment variable to be set. http_expect calls disabled"
}

# $1 = URL
# $2 = get param json_dict
# $3 = http headers json_dict
# $4 = response string
http_expect_get() {
    assert_http_testing
 
    _X_EXPECTED_KEY="$( jq -n \
        --arg url "$1" \
        --arg params "$2" \
        --arg headers "$3" \
        '{url: $url, headers: $headers, params: $params}'
    )"
    _X_EXPECTED_SHA=$(echo "$_X_EXPECTED_KEY" | shasum)

    _X_EXPECTED_DATA="$( jq -n \
        --arg url "$1" \
        --arg params "$2" \
        --arg headers "$3" \
        --arg response "$4" \
        '{url: $url, headers: $headers, params: $params, response: $response}'
    )"

    _X_EXPECT_HTTP_GET="$( echo "$_X_EXPECT_HTTP_GET" | \
        jq \
            --arg sha "$_X_EXPECTED_SHA" \
            --arg data "$_X_EXPECTED_DATA" \
            '. += { ($sha): $data }' \
    )"
}

# $1 = URL
# $2 = data string
# $3 = http headers json_dict
# $4 = response string
http_expect_post() {
    assert_http_testing

    _X_EXPECTED_KEY="$( jq -n \
        --arg url "$1" \
        --arg data "$2" \
        --arg headers "$3" \
        '{url: $url, headers: $headers, data: $data}'
    )"
    _X_EXPECTED_SHA=$(echo "$_X_EXPECTED_KEY" | shasum)

    _X_EXPECTED_DATA="$( jq -n \
        --arg url "$1" \
        --arg data "$2" \
        --arg headers "$3" \
        --arg response "$4" \
        '{url: $url, headers: $headers, data: $data, response: $response}'
    )"

    _X_EXPECT_HTTP_POST="$( echo "$_X_EXPECT_HTTP_POST" | \
        jq \
            --arg sha "$_X_EXPECTED_SHA" \
            --arg data "$_X_EXPECTED_DATA" \
            '. += { ($sha): $data }' \
    )"
}

# This function should take the same params as http_get
# $1 = URL
# $2 = get param json_dict
# $3 = http headers json_dict
http_test_get() {
    assert_http_testing

    _X_EXPECTED_KEY="$( jq -n \
        --arg url "$1" \
        --arg params "$2" \
        --arg headers "$3" \
        '{url: $url, headers: $headers, params: $params}'
    )"
    _X_EXPECTED_SHA=$(echo "$_X_EXPECTED_KEY" | shasum)

    _X_CALL_INFO=$(echo "$_X_EXPECT_HTTP_GET" | jq --raw-output --arg key "$_X_EXPECTED_SHA" '.[$key]')
    assert_zero $? "Could not find expectation for http get call to $1 params: $2 headers: $3"

    if [ "X$_X_CALL_INFO" == "X" ]; then
        fatal "Empty expectation set for http get call to $1 params: $2 headers: $3"
    fi

    _X_EXPECTED_URL="$(echo "$_X_CALL_INFO" | jq --raw-output '.url')"
    assert_zero $? "Could not extract url from call info"
    assert_equal "$_X_EXPECTED_URL" "$1" "expected URL did not match"

    _X_EXPECTED_PARAMS="$(echo "$_X_CALL_INFO" | jq --raw-output '.params')"
    assert_zero $? "Could not extract http get params from call info"
    assert_equal "$_X_EXPECTED_PARAMS" "$2" "expected GET variable map did not match"

    _X_EXPECTED_HEADERS="$(echo "$_X_CALL_INFO" | jq --raw-output '.headers')"
    assert_zero $? "Could not extract http headers from call info"
    assert_equal "$_X_EXPECTED_HEADERS" "$3" "expected HTTP headers map did not match"
    
    echo "$_X_CALL_INFO" | jq --raw-output '.response'
    assert_zero $? "Could not extract response from call info"
}

# This function should take the same params as http_post
# $1 = URL
# $2 = post data string
# $3 = http headers json_dict
http_test_post() {
    assert_http_testing

    _X_EXPECTED_KEY="$( jq -n \
        --arg url "$1" \
        --arg data "$2" \
        --arg headers "$3" \
        '{url: $url, headers: $headers, data: $data}'
    )"
    _X_EXPECTED_SHA=$(echo "$_X_EXPECTED_KEY" | shasum)

    _X_CALL_INFO=$(echo "$_X_EXPECT_HTTP_POST" | jq --raw-output --arg key "$_X_EXPECTED_SHA" '.[$key]')
    assert_zero $? "Could not find expectation for http get call to $1 data: $2 headers: $3"

    if [ "X$_X_CALL_INFO" == "X" ]; then
        fatal "Empty expectation set for http post call to $1 data: $2 headers: $3"
    fi

    _X_EXPECTED_URL="$(echo "$_X_CALL_INFO" | jq --raw-output '.url')"
    assert_zero $? "Could not extract url from expected call info"
    assert_equal "$_X_EXPECTED_URL" "$1" "Expected URL did not match"

    _X_EXPECTED_DATA="$(echo "$_X_CALL_INFO" | jq --raw-output '.data')"
    assert_zero $? "Could not extract http post data from call info"
    assert_equal "$_X_EXPECTED_DATA" "$2" "Expected http post data did not match"

    _X_EXPECTED_HEADERS="$(echo "$_X_CALL_INFO" | jq --raw-output '.headers')"
    assert_zero $? "Could not extract headers from call info"
    assert_equal "$_X_EXPECTED_HEADERS" "$3" "Expected http post headers did not match"
    
    echo "$_X_CALL_INFO" | jq --raw-output '.response'
    assert_zero $? "Could not extract response from $_X_CALL_INFO"
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

    if is_http_testing; then
        http_test_get "$@"
        return 
    fi

    _X_HEADERS=$(http_json_dict_to_header_params "$3")
    assert_zero $? "Could not create header params from $3"

    _X_QUERY_STRING=$(http_json_dict_to_query_string "$2")
    assert_zero $? "Could not create query string from $2"
    
    _X_FULL_URL="$1"
    if [ "X$_X_QUERY_STRING" != "X" ]; then
        _X_FULL_URL="$_X_FULL_URL?$_X_QUERY_STRING"
    fi

    "$CURL_EXE" -s $_X_HEADERS "$_X_FULL_URL" 
    assert_zero $? "Could not GET $_X_FULL_URL with headers $3"
}

# $1 = URL
# $2 = post data
# $3 = http headers json_dict
http_post() {

    if is_http_testing; then
        http_test_post "$@"
        return 
    fi

    _X_HEADERS=$(http_json_dict_to_header_params "$3")
    assert_zero $? "Could not create header params from $3"

    "$CURL_EXE" -s $_X_HEADERS -d "$2" "$1" 
    assert_zero $? "Could not POST to $1 with headers $3"
}

fi
