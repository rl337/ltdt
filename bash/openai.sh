
if [ "X$_X_OPENAI_LIB_" == "X" ]; then
_X_OPENAI_LIB_=true

if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"

OPENAI_API_BASE_URL="https://api.openai.com"
OPENAI_TEXT_MODEL=text-davinci-003



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


# $1 = specific api, example v1/completions
# $2 = data
openai() {
    _X_FULL_API_URL="$OPENAI_API_BASE_URL/$1"

    if [ "X$OPENAI_API_KEY" == "X" ]; then
        fatal "OPENAI_API_KEY environment variable must be set"
    fi

    if [ "X$DEBUG" != "X" ]; then
        debug_openai "$1" "$2" 
        return $?
    fi
    
    curl -s "$_X_FULL_API_URL" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "$2"
    if [ $? -ne 0 ]; then
        fatal "Could not curl $_X_FULL_API_URL"
    fi
}



# $1 = model to use
# $2 = prompt_file
# $3 = max_tokens
completions() {

_X_PROMPT=$(cat "$2")

_X_DATA=$( jq -n \
  --arg model "$1" \
  --arg prompt "$_X_PROMPT" \
  --arg max_tokens "$3" \
  '{model: $model, prompt: $prompt, max_tokens: $max_tokens|fromjson}'
)

    openai "v1/completions" "$_X_DATA" 
}


# $1 prompt_file
# $2 size 1024x1024, 512x512, 256x256
images_generations() {

_X_PROMPT=$(cat "$1")
_X_DATA=$(cat <<END
{
   "prompt": "$_X_PROMPT",
   "n": 1,
   "size": "$2",
   "response_format": "b64_json"
}
END
)

    openai "v1/images/generations" "$_X_DATA"
}


# $1 = response file
extract_completions_response() {
    cat "$1" | jq -e --raw-output '.choices[0].text'
    if [ $? -ne 0 ]; then
        fatal "Could not extract completin from from $1"
    fi
}

# $1 = response file
# $2 output file
extract_images_generations_response() {
    _TMP_BASE64_FILE="${2}.base64"
    jq -e --raw-output '.data[0].b64_json' "$1" > "$_TMP_BASE64_FILE"
    if [ $? -ne 0 ]; then
        fatal "Could not extract image base64 data from $1"
    fi

    base64 -d "$_TMP_BASE64_FILE" > "$2"
    if [ $? -ne 0 ]; then
        fatal "Could not decode base64 data from $_TMP_BASE64_FILE"
    fi
}

fi
