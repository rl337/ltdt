
if [ "X$_X_BLOCKADE_LIB_" == "X" ]; then
_X_BLOCKADE_LIB_=true

if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asset_management.sh"

BLOCKADE_API_BASE_URL="https://backend.blockadelabs.com/api"


# $1 = specific api, example v1/generators
# $2 = data, urlencoded get params not including leading ?
blockade_get() {
    _X_FULL_API_URL="$BLOCKADE_API_BASE_URL/$1"

    if [ "X$BLOCKADE_API_KEY" == "X" ]; then
        fatal "BLOCKADE_API_KEY environment variable must be set"
    fi

    _X_FULL_API_URL_WITH_PARAMS="$_X_FULL_API_URL?api_key=$BLOCKADE_API_KEY&$2"

    curl -s "$_X_FULL_API_URL_WITH_PARAMS" 
    if [ $? -ne 0 ]; then
        fatal "Could not curl $_X_FULL_API_URL"
    fi
}

# $1 = specific api, example v1/completions
# $2 = data
blockade_post() {
    _X_FULL_API_URL="$BLOCKADE_API_BASE_URL/$1"

    if [ "X$BLOCKADE_API_KEY" == "X" ]; then
        fatal "BLOCKADE_API_KEY environment variable must be set"
    fi

    curl -s "$_X_FULL_API_URL" \
        -H 'Content-Type: application/json' \
        -d "$2"
    if [ $? -ne 0 ]; then
        fatal "Could not curl $_X_FULL_API_URL"
    fi
}


# $1 prompt asset_id
stable_skybox() {
    if [ "X$BLOCKADE_API_KEY" == "X" ]; then
        fatal "BLOCKADE_API_KEY environment variable must be set"
    fi

    assert_file_exists "$1"
    assert_valid_asset "$2"
    file_exists "$2"
    if [ $? -eq 0 ]; then
        info "output asset already exists: $2 ($(asset_path $2))"
        return 0
    fi

    _X_PROMPT_FILE=$(asset_path "$1")
    _X_PROMPT=$(cat "$_X_PROMPT_FILE")

_X_DATA=$(cat <<END
{
   "api_key": "$BLOCKADE_API_KEY",
   "generator": "stable-skybox",
   "prompt": "$_X_PROMPT"
}
END
)

    blockade_post "v1/imagine/requests" "$_X_DATA"
}

# $1 request id
request_status() {
    blockade_get "v1/imagine/requests/$1"
}

# takes no params
generators() {
    blockade_get "v1/generators"
}

# $1 prompt asset_id
# $2 output image asset_id
generate_skybox_from_prompt() {
    assert_is_prompt "$1"
    assert_file_exists "$1"

    file_exists "$2"
    if [ $? == 0 ]; then
        info "image asset already exists: $2 ($(asset_path $2))"
        return 0
    fi 

    _TMP_RESPONSE=$(suffix_asset "$2" create_response)
    _TMP_RESPONSE_PATH=$(asset_path "$_TMP_RESPONSE")

    stable_skybox "$1" "$2" > "$_TMP_RESPONSE_PATH" > "$_TMP_RESPONSE_PATH"
    _X_REQUEST_ID=$(cat "$_TMP_RESPONSE_PATH" | jq -e -r .request.id)
    if [ $? -ne 0 ]; then
        fatal "Could not get response id"
    fi

    _X_CURRENT_PROGRESS=$(request_status "$_X_REQUEST_ID" | jq .request.progress)
    if [ $? -ne 0 ]; then
        fatal "Could not get initial status for $_X_REQUEST_ID"
    fi
    while [ $_X_CURRENT_PROGRESS -lt 100 ]; do
        sleep 15
        _X_CURRENT_PROGRESS=$(request_status "$_X_REQUEST_ID" | jq .request.progress)
        if [ $? -ne 0 ]; then
            fatal "Could not get incremental status for $_X_REQUEST_ID"
        fi
    done

    _X_RESPONSE_FINAL=$(suffix_asset "$2" final_response)
    _X_RESPONSE_FINAL_FILE=$(asset_path "$_X_RESPONSE_FINAL")
    request_status "$_X_REQUEST_ID" > "$_X_RESPONSE_FINAL_FILE"

    _X_FINAL_STATUS=$(cat "$_X_RESPONSE_FINAL_FILE" | jq -r .request.status)
    if [ $? -ne 0 ]; then
        fatal "Could not extract status from last response"
    fi

    if [ "X$_X_FINAL_STATUS" != "Xcomplete" ]; then
        fatal "Unexpected status for request $_X_REQUEST_ID: $_X_FINAL_STATUS"
    fi

    _X_SKYBOX_URL=$(cat "$_X_RESPONSE_FINAL_FILE" | jq -r .request.file_url)
    if [ $? -ne 0 ]; then
        fatal "Could not extract file_url from last response"
    fi
    if [ "X$_X_SKYBOX_URL" == "X" ]; then
        fatal "Got an empty file url from last response"
    fi

    _TMP_OUTPUT_FILE=$(asset_path "$2")
    curl -s "$_X_SKYBOX_URL" > "$_TMP_OUTPUT_FILE"
}

fi
