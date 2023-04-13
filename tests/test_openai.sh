SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/../bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/openai.sh"
. "$BASH_DIR/testing.sh"



setup_http_test_env() {
    HTTP_TESTING=1
    OPENAI_API_KEY="API_KEY_$$"

    export HTTP_TESTING OPENAI_API_KEY
}
   
setup_set_asset_root() {
    ASSET_ROOT="$TEST_DIR"
    ROOT_ASSET="${TEST_NAME}_asset"

    export ASSET_ROOT ROOT_ASSET
    info "Asset root: $ASSET_ROOT, Root asset: $ROOT_ASSET"
}


# $1 model string
# $2 prompt string
# $3 max_tokens int
# $4 expected_completion string
expect_openai_completions() {
    _X_PROMPT_TOKENS=$(echo "$2" | wc -w)
    _X_COMPLETION_TOKENS=$(echo "$4" | wc -w)
    _X_TOTAL_TOKENS=$(expr $_X_PROMPT_TOKENS + $_X_COMPLETION_TOKENS)

    _X_OPENAI_REQUEST="$(jq -S -c -n \
        --arg model "$1" \
        --arg prompt "$2" \
        --argjson tokens $3 \
        '{"model": $model,  "prompt": $prompt,  "max_tokens": $tokens}' \
    )"

    _X_OPENAI_HEADERS="$(jq -S -c -n \
        --arg api_token "Bearer $OPENAI_API_KEY" \
        '{"Content-Type": "application/json", "Authorization": $api_token}' \
    )"

    _X_CALL_DATE=`date '+%s'`
    _X_OPENAI_EXPECTED_RESPONSE="$(jq -S -c -n \
        --arg id 'cmpl-some_random_id' \
        --arg created "$_X_CALL_DATE" \
        --arg model "$1" \
        --arg completion "$4" \
        --argjson pt $_X_PROMPT_TOKENS \
        --argjson ct $_X_COMPLETION_TOKENS \
        --argjson tt $_X_TOTAL_TOKENS \
        '{"id":$id, "object":"text_completion","created":$created,"model":$model,"choices":[{"text":$completion,"index":0,"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":$pt,"completion_tokens":$ct,"total_tokens":$tt}}'\
    )"
    http_expect_post "https://api.openai.com/v1/completions" "$_X_OPENAI_REQUEST" "$_X_OPENAI_HEADERS" "$_X_OPENAI_EXPECTED_RESPONSE"
}

# $1 prompt string
# $2 n int
# $3 size string
# $4 expected_base64_image string
expect_openai_image() {
    _X_OPENAI_REQUEST="$(jq -S -c -n \
        --arg prompt "$1" \
        --argjson n $2 \
        --arg size "$3" \
        '{"prompt": $prompt, "n": $n, "size": $size, "response_format": "b64_json" }'
    )"

    _X_OPENAI_HEADERS="$(jq -n -S -c\
        --arg api_token "Bearer $OPENAI_API_KEY" \
        '{"Content-Type": "application/json", "Authorization": $api_token}' \
    )"

    _X_CALL_DATE=`date '+%s'`
    _X_OPENAI_EXPECTED_RESPONSE="$(jq -S -c -n \
        --arg created "$_X_CALL_DATE" \
        --arg b64_json "$4" \
        '{"created": $created, "data": [{ "b64_json": $b64_json }]}' \
    )"

    http_expect_post "https://api.openai.com/v1/images/generations" "$_X_OPENAI_REQUEST" "$_X_OPENAI_HEADERS" "$_X_OPENAI_EXPECTED_RESPONSE"
}

test_openai_alone() {   
    EXPECTED_RESPONSE='{"payload": "I am a fake response"}'
    EXPECTED_DATA='{"data": "this is my random post data "}'
    EXPECTED_HEADERS=$(jq -S -c -n --arg api_token "Bearer $OPENAI_API_KEY" '{"Content-Type": "application/json", "Authorization": $api_token}')

    http_expect_post "https://api.openai.com/v1/omg" "$EXPECTED_DATA" "$EXPECTED_HEADERS" "$EXPECTED_RESPONSE"

    ACTUAL_RESPONSE=$(openai "v1/omg" "$EXPECTED_DATA")
    assert_zero $? "openai call returned non-zero"
    assert_equal "$EXPECTED_RESPONSE" "$ACTUAL_RESPONSE"
}

test_openai_generate_completion_from_prompt() {
    TEST_PROMPT="If i were a rich man"
    EXPECTED_COMPLETION="what is the film fiddler on the roof"

    expect_openai_completions "$OPENAI_TEXT_MODEL" "$TEST_PROMPT" 2048 "$EXPECTED_COMPLETION"

    TEST_PROMPT_ASSET=$(sub_asset "$ROOT_ASSET" "test_prompt")
    create_prompt_from_string "$TEST_PROMPT" "$TEST_PROMPT_ASSET"

    TEST_COMPLETION_ASSET=$(sub_asset "$ROOT_ASSET" "completion")
    openai_generate_completion_from_prompt "$TEST_PROMPT_ASSET" "$TEST_COMPLETION_ASSET"

    assert_file_exists "$TEST_COMPLETION_ASSET"
    PROMPT_PATH=$(asset_path "$TEST_COMPLETION_ASSET")
    ACTUAL_COMPLETION=$(cat "$PROMPT_PATH")
    assert_equal "$EXPECTED_COMPLETION" "$ACTUAL_COMPLETION"
}

test_openai_generate_image_from_prompt() {
    TEST_PROMPT="If i were a rich man"
    EXPECTED_IMAGE_BASE64="/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="

    expect_openai_image "$TEST_PROMPT" 1 "1024x1024" "$EXPECTED_IMAGE_BASE64"
    
    TEST_PROMPT_ASSET=$(sub_asset "$ROOT_ASSET" "test_prompt")
    create_prompt_from_string "$TEST_PROMPT" "$TEST_PROMPT_ASSET"

    TEST_IMAGE_ASSET=$(sub_asset "$ROOT_ASSET" "profile_image")
    openai_generate_image_from_prompt "$TEST_PROMPT_ASSET" "$TEST_IMAGE_ASSET"

    TEST_IMAGE_PATH=$(asset_path "$TEST_IMAGE_ASSET")
    ACTUAL_IMAGE_BASE64=$(cat "$TEST_IMAGE_PATH" | base64)
    assert_equal "$EXPECTED_IMAGE_BASE64" "$ACTUAL_IMAGE_BASE64"
}

run_all_tests "$@"
