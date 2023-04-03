SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/../bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/openai.sh"
. "$BASH_DIR/testing.sh"

DEBUG_LOREM_IPSUM_COMPLETION="\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus tristique luctus tellus quis accumsan. Morbi blandit, nibh faucibus vehicula gravida, sem neque tempus libero, dapibus porta ante lorem semper tortor. Donec purus nisi, porttitor vel pharetra nec, pharetra sed purus. Etiam rutrum condimentum mi ut tristique."
DEBUG_CHARACTER_LIST_COMPLETION="\n\nList of Characters in csv format:\n\ncharacter_Lorem_Ipsum.json,Lorem Ipsum,dolor sit amet\ncharacter_consectetur_elit.json,Consectetur Elit, Vivamus tristique luctus tellus "
DEBUG_CHARACTER_ATTRIBUTES_COMPLETION="\n\nList of Character Attributes in csv format:\n\nname,Lorem Ipsum\nage,dolor\nsex,sit\nhair color,amet\nbirthdate,consectetur\nzodiac sign,elit\nblood type,vivamus\nbirth place,tristique "


# $1 = specific api
# $2 = data
debug_openai() {

    _X_CALL_DATE=`date '+%s'`

    case "$1" in

        v1/completions)
            _X_COMPLETION_DATA="$DEBUG_LOREM_IPSUM_COMPLETION"
            echo "$2" | grep 'csv format' > /dev/null
            if [ $? -eq 0 ]; then
                _X_COMPLETION_DATA="$DEBUG_CHARACTER_LIST_COMPLETION"
                echo "$2" | grep 'character attributes' > /dev/null
                if [ $? -eq 0 ]; then
                    _X_COMPLETION_DATA="$DEBUG_CHARACTER_ATTRIBUTES_COMPLETION"
                fi
            fi
_X_DATA=$(cat <<END
{"id":"cmpl-6onzloyRUV3oIUZQag98WE4qp8cmc","object":"text_completion","created":$_X_CALL_DATE,"model":"$OPENAI_TEXT_MODEL","choices":[{"text":"$_X_COMPLETION_DATA","index":0,"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":265,"completion_tokens":105,"total_tokens":370}}
END
)
            ;;
        v1/images/generations)
_X_DATA=$(cat <<END
{
  "created": $_X_CALL_DATE,
  "data": [
    {
      "b64_json": "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="
    }
  ]
}
END
)
            ;;
        *)
            fatal "Unknown api call $1"
    esac
    echo -n "$_X_DATA"
}


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

    _X_OPENAI_REQUEST="$(jq -n \
        --arg model "$1" \
        --arg prompt "$2" \
        --argjson tokens $3 \
        '{"model": $model,  "prompt": $prompt,  "max_tokens": $tokens}' \
    )"

    _X_OPENAI_HEADERS="$(jq -n \
        --arg api_token "Bearer $OPENAI_API_KEY" \
        '{"Content-Type": "application/json", "Authorization": $api_token}' \
    )"

    _X_CALL_DATE=`date '+%s'`
    _X_OPENAI_EXPECTED_RESPONSE="$(jq -n \
        --arg id 'cmpl-some_random_id' \
        --arg created "$X_CALL_DATE" \
        --arg model "$1" \
        --arg completion "$4" \
        --argjson pt $_X_PROMPT_TOKENS \
        --argjson ct $_X_COMPLETION_TOKENS \
        --argjson tt $_X_TOTAL_TOKENS \
        '{"id":$id, "object":"text_completion","created":$created,"model":$model,"choices":[{"text":$completion,"index":0,"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":$pt,"completion_tokens":$ct,"total_tokens":$tt}}'\
    )"
    http_expect_post "https://api.openai.com/v1/completions" "$_X_OPENAI_REQUEST" "$_X_OPENAI_HEADERS" "$_X_OPENAI_EXPECTED_RESPONSE"
}

test_openai() {   
    EXPECTED_RESPONSE='{"payload": "I am a fake response"}'
    EXPECTED_DATA='{"data": "this is my random post data "}'
    EXPECTED_HEADERS=$(jq -n --arg api_token "Bearer $OPENAI_API_KEY" '{"Content-Type": "application/json", "Authorization": $api_token}')

    http_expect_post "https://api.openai.com/v1/omg" "$EXPECTED_DATA" "$EXPECTED_HEADERS" "$EXPECTED_RESPONSE"

    ACTUAL_RESPONSE=$(openai "v1/omg" "$EXPECTED_DATA")
    assert_zero $? "openai call returned non-zero"
    assert_equal "$EXPECTED_RESPONSE" "$ACTUAL_RESPONSE"
}

test_openai_generate_completion_from_prompt() {
    TEST_PROMPT="If i were a rich man"
    EXPECTED_COMPLETION="what is the film fiddler on the roof"

# $1 model string
# $2 prompt string
# $3 max_tokens int
# $4 expected_completion string
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

run_all_tests
