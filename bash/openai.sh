
if [ "X$_X_OPENAI_LIB_" == "X" ]; then
_X_OPENAI_LIB_=true

if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asset_management.sh"
. "$BASH_DIR/http.sh"

OPENAI_API_BASE_URL="https://api.openai.com"
OPENAI_TEXT_MODEL=text-davinci-003

# $1 = specific api, example v1/completions
# $2 = data
openai() {
    _X_FULL_API_URL="$OPENAI_API_BASE_URL/$1"

    if [ "X$OPENAI_API_KEY" == "X" ]; then
        fatal "OPENAI_API_KEY environment variable must be set"
    fi

    _X_POST_HEADERS=$(jq -n -S -c --raw-output \
        --arg api_key "Bearer $OPENAI_API_KEY" \
        '{"Content-Type": "application/json", "Authorization": $api_key}' \
    )
    http_post \
        "$_X_FULL_API_URL" \
        "$2" \
        "$_X_POST_HEADERS"
    assert_zero $? "Could not post API request to $_X_FULL_API_URL"
}

# $1 = model to use
# $2 = prompt_file
# $3 = max_tokens
openai_completions() {
    assert_valid_asset "$2"

    _X_PROMPT_FILE=$(asset_path "$2")
    _X_PROMPT=$(cat "$_X_PROMPT_FILE")

_X_DATA=$( jq -n -S -c --raw-output \
  --arg model "$1" \
  --arg prompt "$_X_PROMPT" \
  --arg max_tokens "$3" \
  '{model: $model, prompt: $prompt, max_tokens: $max_tokens|fromjson}'
)

    openai "v1/completions" "$_X_DATA" 
}


# $1 prompt asset_id
# $2 size 1024x1024, 512x512, 256x256
openai_images_generations() {

_X_PROMPT_FILE=$(asset_path "$1")
_X_PROMPT=$(cat "$_X_PROMPT_FILE")
_X_DATA=$( jq -n -S -c --raw-output \
  --arg prompt "$_X_PROMPT" \
  --arg size "$2" \
  '{"prompt": $prompt, "n": 1, "size": $size, "response_format": "b64_json"}'
)

    openai "v1/images/generations" "$_X_DATA"
}



# $1 = response asset_id
openai_extract_completions_response() {
    assert_file_exists "$1"

    _X_RESPONSE_FILE=$(asset_path "$1")
    cat "$_X_RESPONSE_FILE" | jq -e --raw-output '.choices[0].text'
    if [ $? -ne 0 ]; then
        fatal "Could not extract completion from from $1 ($_X_RESPONSE_FILE)"
    fi
}

# $1 = response asset
# $2 = output asset
openai_extract_images_generations_response() {
    assert_file_exists "$1"

    file_exists "$2"
    if [ $? -eq 0 ]; then
        info "image asset already exists: $2 ($(asset_path $2))"
        return 0
    fi
    _TMP_RESPONSE_FILE=$(asset_path "$1")

    _TMP_BASE64=$(suffix_asset "$2" base64)
    _TMP_BASE64_FILE=$(asset_path "$_TMP_BASE64")
    file_exists "$_TMP_BASE64"
    if [ $? -ne 0 ]; then
        jq -e --raw-output '.data[0].b64_json' "$_TMP_RESPONSE_FILE" > "$_TMP_BASE64_FILE"
        if [ $? -ne 0 ]; then
            fatal "Could not extract image base64 data from $1"
        fi
    fi

    _TMP_OUTPUT_FILE=$(asset_path "$2")
    base64 -d "$_TMP_BASE64_FILE" > "$_TMP_OUTPUT_FILE"
    if [ $? -ne 0 ]; then
        fatal "Could not decode base64 data from $_TMP_BASE64_FILE"
    fi
}

# $1 prompt asset_id
# $2 output asset_id
# $3 optional filter
openai_generate_completion_from_prompt() {
    assert_is_prompt "$1"
    assert_file_exists "$1"

    assert_valid_asset "$2"
    file_exists "$2"
    if [ $? -eq 0 ]; then
        info "output asset already exists: $2 ($(asset_path $2))"
        return 0
    fi

    _TMP_RESPONSE=$(suffix_asset "$2" "response")
    _TMP_RESPONSE_PATH=$(asset_path "$_TMP_RESPONSE")
    file_exists "$_TMP_RESPONSE"
    if [ $? -eq 0 ]; then
        info "response for $2 already exists: $_TMP_RESPONSE"
    else
        openai_completions $OPENAI_TEXT_MODEL "$1" 2048 > "$_TMP_RESPONSE_PATH"
    fi

    _TMP_OUTPUT_PATH=$(asset_path "$2")
    if [ "X$4" == "X" ]; then
        openai_extract_completions_response "$_TMP_RESPONSE" > "$_TMP_OUTPUT_PATH"
    else
        openai_extract_completions_response "$_TMP_RESPONSE" | grep "$3" > "$_TMP_OUTPUT_PATH"
    fi
}


# $1 prompt asset_id
# $2 output image asset_id
openai_generate_image_from_prompt() {
    assert_is_prompt "$1"
    assert_file_exists "$1"

    assert_valid_asset "$2"
    file_exists "$2"
    if [ $? == 0 ]; then
        info "image asset already exists: $2 ($(asset_path $2))"
        return 0
    fi

    _TMP_RESPONSE=$(suffix_asset "$2" response)
    _TMP_RESPONSE_PATH=$(asset_path "$_TMP_RESPONSE")
    file_exists "$_TMP_RESPONSE"
    if [ $? -eq 0 ]; then
        info "response for $2 already exists: $_TMP_RESPONSE_PATH"
    else
        openai_images_generations "$1" 1024x1024 > "$_TMP_RESPONSE_PATH"
    fi

    openai_extract_images_generations_response "$_TMP_RESPONSE" "$2"
}


# $1 = preamble string
# $2 = context asset_id
# $3 = completion asset_id
# $4 = optional suffix string
openai_generate_completion_from_preamble_and_context() {
    assert_valid_asset "$3"
    assert_is_context "$2"

    _X_COMPLETION_PROMPT=$(suffix_asset "$3" "prompt")
    create_prompt_from_preamble_and_context "$_X_COMPLETION_PROMPT" "$1" "$2" "$4"
    openai_generate_completion_from_prompt "$_X_COMPLETION_PROMPT" "$3"
}

fi
