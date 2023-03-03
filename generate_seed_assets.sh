#!/bin/bash

OPENAI_API_BASE_URL="https://api.openai.com"
OPENAI_TEXT_MODEL=text-davinci-003

mesg() {
    _X_PREFIX=`date`

    echo "$_X_PREFIX $*" 1>&2
}

info() {
    mesg "INFO $*"
}

fatal() {
    mesg "FATAL $*"
    exit -1
}


if [ "X$OPENAI_API_KEY" == "X" ]; then
    fatal "OPENAI_API_KEY environment variable must be set"
fi


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
        fatal "Could not extract response from $1"
    fi
}


# $1 file to append from
# $2 destination file
# $1 and $2 must not be the same file
append_prompt_file() {
    if [ ! -f "$1" ]; then
        fatal "file to append from does not exist: $1"
    fi

    if [ ! -f "$2" ]; then
        fatal "file to append to does not exist: $2"
    fi

    cat "$1" | tr '\r\n\t' '   ' | sed -e 's/[ ][ ]*/ /g' | sed -e "s/\([0-9][0-9]*\)'[ ]*\([0-9][0-9]*\)\"/\1 ft \2 in/g" >> "$2"
    if [ $? -ne 0 ]; then
        fatal "Could not append $1 to $2"
    fi
}

# $1 string to append 
# $2 destination file
append_string_to_prompt_file() {
    if [ ! -f "$2" ]; then
        fatal "file to append to does not exist: $2"
    fi

    _X_ADDENDUM=`echo -n "$1" | tr '\r\n\t' '   ' | sed -e 's/[ ][ ]*/ /g' | sed -e "s/\([0-9][0-9]*\)'[ ]*\([0-9][0-9]*\)\"/\1 ft \2 in/g"`
    cat "$2" | grep "$_X_ADDENDUM" > /dev/null
    if [ $? -eq 0 ]; then
        info "String already appended to $2"
        return 0
    fi

    echo -n "$_X_ADDENDUM"  >> "$2"
    if [ $? -ne 0 ]; then
        fatal "Could not add to prompt file: $1"
    fi
}

# $1 preamble
# $2 destination file
# $3 optional file to append to preamble
create_prompt_file() {
    if [ -f "$2" ]; then
        info "prompt file already exists: $2"
        return
    fi

    echo -n "$1" | tr '\r\n\t' '   ' | sed -e 's/[ ][ ]*/ /g' | sed -e "s/\([0-9][0-9]*\)'[ ]*\([0-9][0-9]*\)\"/\1 ft \2 in/g"  > "$2"
    if [ $? -ne 0 ]; then
        fatal "Could not create prompt file: $1"
    fi

    if [ "X$3" == "X" ]; then
        return 0
    fi

    append_prompt_file "$3" "$2"
}


# $1 prompt file
# $2 completion_name
# $3 output file
# $4 optional filter
generate_completion_from_prompt() {

    if [ ! -f "$1" ]; then
        fatal "prompt file does not exist $1"
    fi

    if [ -f "$3" ]; then
        info "output file for $2 already exists: $3"
        return 0
    fi

    _TMP_RESPONSE_FILE="${SCRATCH_DIR}/${2}_response.json"
    if [ ! -f "$_TMP_RESPONSE_FILE" ]; then
        completions $OPENAI_TEXT_MODEL "$1" 2048 > "$_TMP_RESPONSE_FILE"
    else
        info "response for $2 already exists: $_TMP_RESPONSE_FILE"
    fi

    if [ "X$4" == "X" ]; then
        extract_completions_response "$_TMP_RESPONSE_FILE" > "$3"
    else
        extract_completions_response "$_TMP_RESPONSE_FILE" | grep "$4" > "$3"
    fi
}


# $1 prompt file
# $2 image_name
# $3 output file
generate_image_from_prompt() {
    if [ ! -f "$1" ]; then
        fatal "prompt file does not exist $1"
    fi

    if [ -f "$3" ]; then
        info "output file for $2 already exists: $3"
        return 0
    fi

    _TMP_RESPONSE_FILE="${SCRATCH_DIR}/${2}_response.json"
    if [ ! -f "$_TMP_RESPONSE_FILE" ]; then
        images_generations "$1" 1024x1024 > "$_TMP_RESPONSE_FILE"
    else
        info "response for $2 already exists: $_TMP_RESPONSE_FILE"
    fi

    _TMP_BASE64_FILE="${SCRATCH_DIR}/${2}.base64"
    jq -e --raw-output '.data[0].b64_json' "$_TMP_RESPONSE_FILE" > "$_TMP_BASE64_FILE"
    if [ $? -ne 0 ]; then
        fatal "Could not extract base64 data from $_TMP_RESPONSE_FILE"
    fi

    base64 -d "$_TMP_BASE64_FILE" > "$3"
    if [ $? -ne 0 ]; then
        fatal "Could not decode base64 data from $_TMP_BASE64_FILE"
    fi
}

# $1 original_context_file
# $2 new_context_name
# $3 new_context_file
# $4 preamble
refine_context_with_preamble() {
    if [ ! -f "$1" ]; then
        fatal "context file for $2 does not exist: $1"
    fi

    if [ -f "3" ]; then
        info "context file for $2 already exists: $1"
    fi$

    _X_NEW_CONTEXT_PROMPT_FILE="$SCRATCH_DIR/${2}_prompt.txt"
    create_prompt_file "$4" "$_X_NEW_CONTEXT_PROMPT_FILE" "$1"
    generate_completion_from_prompt "$_X_NEW_CONTEXT_FILE" "$2" "$3"
}

if [ "X$1" == "X" ]; then
    fatal "Usage: $0 <story_id> <initial_prompt>"
fi
STORY_ID="$1"

if [ "X$2" == "X" ]; then
    fatal "Usage: $0 <story_id> <original_prompt>"
fi

DATA_DIR=./stories
SCRATCH_DIR="$DATA_DIR/$STORY_ID"

if [ ! -d "$SCATCH_DIR" ]; then
    mkdir -p "$SCRATCH_DIR"
    if [ $? -ne 0 ]; then
        fatal "Could not create scratch directory $SCRATCH_DIR"
    fi
fi

ORIGINAL_PROMPT_FILE="$SCRATCH_DIR/original_prompt.txt"
if [ ! -f "$ORIGINAL_PROMPT_FILE" ]; then
    # record and store the original user prompt
    echo "$2" > "$ORIGINAL_PROMPT_FILE"
    info "Using initial prompt: $2"
    info "Creating Original prompt file: $ORIGINAL_PROMPT_FILE"
else
    info "Original prompt File already exists: $ORIGINAL_PROMPT_FILE"
fi

# create the initial complete prompt file with prompt instruction
INITIAL_PROMPT_PREAMBLE="Given the following prompt, if not already specified choose a setting from an arbitrary selection of top 25 countries by GDP other than the United States. If not already specified, choose an arbitrary time period for the story.  valid time periods are prehistoric, feudal, renaissance, post industrial, modern, or futuristic. Summarize a story using the Pixar method.  the story should take place in a few key concrete locations and involve both main characters and supporting roles. Half of the roles should be from a different country. If a role represents a group of people create a two or three representative individuals. Give each character a full name an age and description. Create a detailed description of this context including all locations, characters and a synopsis of how all of the story elements are related. "

INITIAL_PROMPT_FILE="$SCRATCH_DIR/initial_prompt.txt"
create_prompt_file "$INITIAL_PROMPT_PREAMBLE" "$INITIAL_PROMPT_FILE" "$ORIGINAL_PROMPT_FILE"

MAIN_CONTEXT_FILE="$SCRATCH_DIR/main_context.txt"
info "Creating main context file: $MAIN_CONTEXT_FILE"
generate_completion_from_prompt "$INITIAL_PROMPT_FILE" main_context "$MAIN_CONTEXT_FILE"

# $1 original_context_file
# $2 new_context_name
# $3 new_context_file
# $4 preamble
# refine_context_with_preamble "$ORIGINAL_PROMPT_FILE" main_context "$MAIN_CONTEXT_FILE" "$INITIAL_PROMPT_PREAMBLE"

CHARACTER_LIST_PREAMBLE="Given the following context if there are roles representing a group of people, create two or three representative characters from that group. Give each character a full name, age, sex, hair color, eye color, birth date, a zodiac sign consistent with their birth date, blood type, birth place,  and description. create a list of all characters in the story in csv format where the first column is a unix filename based on the name of the character with spaces converted into underscores and is prefixed with character and has a .json extension.  The second column is the full name of the character.  The third column is a brief description of the character's role in the story."
CHARACTER_LIST_PROMPT_FILE="$SCRATCH_DIR/character_list_prompt.txt"
create_prompt_file "$CHARACTER_LIST_PREAMBLE" "$CHARACTER_LIST_PROMPT_FILE" "$MAIN_CONTEXT_FILE"

CHARACTER_LIST_CSV="$SCRATCH_DIR/character_list.csv"
generate_completion_from_prompt "$CHARACTER_LIST_PROMPT_FILE" character_list "$CHARACTER_LIST_CSV" .json

CHARACTER_FILES=`cat "$CHARACTER_LIST_CSV" | cut -f 1 -d,`
for CHARACTER_FILE in $CHARACTER_FILES; do
    CHARACTER_FILE_PREFIX=`basename "$CHARACTER_FILE" .json`

    CHARACTER_ROW=`cat "$CHARACTER_LIST_CSV" | grep $CHARACTER_FILE`
    if [ $? -ne 0 ]; then
        fatal "Could not find $CHARACTER_FILE in $CHARACTER_LIST_RESPONSE_FILE"
    fi
    CHARACTER_NAME=`echo -n "$CHARACTER_ROW" | cut -f 2 -d,`

    info "Generating character: $CHARACTER_NAME"

    CHARACTER_CONTEXT_PREAMBLE="given the following context describe the character $CHARACTER_NAME, their motivations their life before the story and their role in the story details should also include age, sex, hair color, eye color, birth date, a zodiac sign consistent with their birth date, blood type and birth place. If their place of birth is not in the setting of the story, describe why they left their birth place"
    CHARACTER_CONTEXT_PROMPT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_context_prompt.txt"
    create_prompt_file "$CHARACTER_CONTEXT_PREAMBLE" "$CHARACTER_CONTEXT_PROMPT_FILE" "$MAIN_CONTEXT_FILE"
    CHARACTER_CONTEXT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_context.txt"
    generate_completion_from_prompt "$CHARACTER_CONTEXT_PROMPT_FILE" "${CHARACTER_FILE_PREFIX}_context" "$CHARACTER_CONTEXT_FILE"

    CHARACTER_ATTRIBUTES_PREAMBLE="given the following character information create a list of character attributes in csv format list where the first column is the name of an attribute and the second column is the value based on the character description. The rows are name, age, sex, hair color, eye color, birthdate, zodiac sign, blood type, and birth place."
    CHARACTER_ATTRIBUTES_PROMPT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_attributes_prompt.txt"
    create_prompt_file "$CHARACTER_ATTRIBUTES_PREAMBLE" "$CHARACTER_ATTRIBUTES_PROMPT_FILE" "$CHARACTER_CONTEXT_FILE"
    CHARACTER_ATTRIBUTES_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_attributes.txt"
    generate_completion_from_prompt "$CHARACTER_ATTRIBUTES_PROMPT_FILE" "${CHARACTER_FILE_PREFIX}_attributes" "$CHARACTER_ATTRIBUTES_FILE"

    CHARACTER_DETAIL_PREAMBLE="given the following context describe the character $CHARACTER_NAME create a detailed physical description of the character including physical features that make them stand out as well as any possessions they will always have on themselves.  The description should also include clothing preferences. "
    CHARACTER_DETAIL_PROMPT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_detail_prompt.txt"
    create_prompt_file "$CHARACTER_DETAIL_PREAMBLE" "$CHARACTER_DETAIL_PROMPT_FILE" "$CHARACTER_CONTEXT_FILE"
    CHARACTER_DETAIL_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_detail.txt"
    generate_completion_from_prompt "$CHARACTER_DETAIL_PROMPT_FILE" "${CHARACTER_FILE_PREFIX}_detail" "$CHARACTER_DETAIL_FILE"

    CHARACTER_PORTRAIT_CONTEXT_PREAMBLE="write a DALL-E prompt for a portrait of the following person that is no longer than 900 characters long. "
    CHARACTER_PORTRAIT_CONTEXT_PROMPT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_portrait_context_prompt.txt"
    create_prompt_file "$CHARACTER_PORTRAIT_CONTEXT_PREAMBLE" "$CHARACTER_PORTRAIT_CONTEXT_PROMPT_FILE" "$CHARACTER_DETAIL_FILE"
    CHARACTER_PORTRAIT_CONTEXT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_portrait_context.txt"
    generate_completion_from_prompt "$CHARACTER_PORTRAIT_CONTEXT_PROMPT_FILE" "${CHARACTER_FILE_PREFIX}_portrait_context" "$CHARACTER_PORTRAIT_CONTEXT_FILE"

    CHARACTER_PORTRAIT_PREAMBLE="take a photographic portrait with a 35mm lens of the following character"
    CHARACTER_PORTRAIT_SUFFIX="35mm, fujifilm, dramatic lighting, cinematic, 4k"
    CHARACTER_PORTRAIT_PROMPT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_portrait_prompt.txt"
    create_prompt_file "$CHARACTER_PORTRAIT_PREAMBLE" "$CHARACTER_PORTRAIT_PROMPT_FILE" "$CHARACTER_PORTRAIT_CONTEXT_FILE"
    append_string_to_prompt_file "$CHARACTER_PORTRAIT_SUFFIX" "$CHARACTER_PORTRAIT_PROMPT_FILE"
    CHARACTER_PORTRAIT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_portrait.jpg"
    generate_image_from_prompt "$CHARACTER_PORTRAIT_PROMPT_FILE" "${CHARACTER_FILE_PREFIX}_portrait" "$CHARACTER_PORTRAIT_FILE"
done
