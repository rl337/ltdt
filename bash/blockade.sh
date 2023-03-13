
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


# $1 prompt 
# $2 negative prompt 
stable_skybox() {

    if [ "X$BLOCKADE_API_KEY" == "X" ]; then
        fatal "BLOCKADE_API_KEY environment variable must be set"
    fi

_X_DATA=$(cat <<END
{
   "api_key": "$BLOCKADE_API_KEY",
   "generator": "stable-skybox",
   "prompt": "$1",
   "negative_text": "$2"
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



fi
