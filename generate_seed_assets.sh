#!/bin/bash

OPENAI_API_BASE_URL="https://api.openai.com"
SCRATCH_DIR=/tmp
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


# $1 = specific api, example v1/completions
# $2 = data
openai() {
    _X_FULL_API_URL="$OPENAI_BASE_URL/$1"
    
    curl -s https://api.openai.com/v1/completions \
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
completion() {

_X_PROMPT=$(cat "$2")
_X_DATA=$(cat <<END
{
   "model": "$1",
   "prompt": "$_X_PROMPT",
   "max_tokens": $3
}
END
)

    openai "v1/completions" "$_X_DATA" 
}

if [ "X$1" == "X" ]; then
    fatal "Usage: $0 <initial prompt>"
fi

# $1 = response file
extract_response() {
    cat "$1" | jq --raw-output '.choices[0].text'
    if [ $? -ne 0 ]; then
        fatal "Could not extract response from $1"
    fi
}

ORIGINAL_PROMPT_FILE="$SCRATCH_DIR/original_prompt.txt"
if [ ! -f "$ORIGINAL_PROMPT_FILE" ]; then
    # record and store the original user prompt
    echo "$1" > "$ORIGINAL_PROMPT_FILE"
    info "Using initial prompt: $1"
    info "Creating Original prompt file: $ORIGINAL_PROMPT_FILE"
else
    info "Original prompt File already exists: $ORIGINAL_PROMPT_FILE"
fi

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

    cat "$1" | tr '\r\n\t' '   ' | sed -e 's/[ ][ ]*/ /g' >> "$2"
    if [ $? -ne 0 ]; then
        fatal "Could not append $1 to $2"
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

    echo -n "$1" | tr '\r\n\t' '   ' | sed -e 's/[ ][ ]*/ /g'  > "$2"
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
        completion $OPENAI_TEXT_MODEL "$1" 2048 > "$_TMP_RESPONSE_FILE"
    else
        info "response for $2 already exists: $_TMP_RESPONSE_FILE"
    fi

    if [ "X$4" == "X" ]; then
        extract_response "$_TMP_RESPONSE_FILE" > "$3"
    else
        extract_response "$_TMP_RESPONSE_FILE" | grep "$4" > "$3"
    fi
}

# create the initial complete prompt file with prompt instruction
INITIAL_PROMPT_PREAMBLE="Given the following prompt, if not already specified choose a setting from an arbitrary selection of top 25 countries by GDP other than the United States, summarize a story using the Pixar method.  the story should take place in a few key concrete locations and involve both main characters and supporting roles.  For each of the roles if the role represents more than one individual character create a few representative individuals. Give each character a full name an age and description. Create a detailed description of this context including all locations, characters and a synopsis of how all of the story elements are related. "

INITIAL_PROMPT_FILE="$SCRATCH_DIR/initial_prompt.txt"
create_prompt_file "$INITIAL_PROMPT_PREAMBLE" "$INITIAL_PROMPT_FILE" "$ORIGINAL_PROMPT_FILE"

MAIN_CONTEXT_FILE="$SCRATCH_DIR/main_context.txt"
info "Creating main context file: $MAIN_CONTEXT_FILE"
generate_completion_from_prompt "$INITIAL_PROMPT_FILE" main_context "$MAIN_CONTEXT_FILE"

CHARACTER_LIST_PREAMBLE="Given the following context For each of the roles if the role represents more than one individual character create a few representative individuals. Give each character a full name, sex, age and description. create a list of all characters in the story in csv format where the first column is a unix filename based on the name of the character with spaces converted into underscores and is prefixed with character and has a .json extension.  The second column is the full name of the character.  The third column is a brief description of the character's role in the story."
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

    CHARACTER_CONTEXT_PREAMBLE="given the following context describe the character $CHARACTER_NAME, their motivations their life before the story and their role in the story. "

    CHARACTER_CONTEXT_PROMPT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_context_prompt.txt"
    create_prompt_file "$CHARACTER_CONTEXT_PREAMBLE" "$CHARACTER_CONTEXT_PROMPT_FILE" "$MAIN_CONTEXT_FILE"

    CHARACTER_CONTEXT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_context.txt"
    generate_completion_from_prompt "$CHARACTER_LIST_PROMPT_FILE" "${CHARACTER_FILE_PREFIX}_context" "$CHARACTER_CONTEXT_FILE"
done
