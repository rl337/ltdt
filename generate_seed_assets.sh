#!/bin/bash

SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asset_management.sh"
. "$BASH_DIR/openai.sh"

GENERATE_CHARACTER_SH="$SCRIPT_DIR/generate_character.sh"
# GENERATE_STORY_SH="$SCRIPT_DIR/generate_story.sh"


if [ "X$1" == "X" ]; then
    fatal "Usage: $0 <story_id> <initial_prompt>"
fi
STORY_ID="$1"

if [ "X$2" == "X" ]; then
    fatal "Usage: $0 <story_id> <original_prompt>"
fi

DATA_DIR=./data
ASSET_ROOT="$DATA_DIR"

export ASSET_ROOT OPENAI_API_KEY DEBUG

ROOT_ASSET=$(root_asset)
STORY_ROOT_ASSET=$(sub_asset "$ROOT_ASSET" "$STORY_ID")
ensure_asset_directory "$STORY_ROOT_ASSET"

STORY_ASSET=$(sub_asset "$STORY_ROOT_ASSET" "story")

USER_PROVIDED_CONTEXT=$(suffix_asset "$STORY_ASSET" "original_context")
create_context_from_string "$2" "$USER_PROVIDED_CONTEXT"

STORY_CONTEXT_PREAMBLE="Given the following prompt, if not already specified choose a setting from an arbitrary selection of top 25 countries by GDP other than the United States. If not already specified, choose an arbitrary time period for the story.  valid time periods are prehistoric, feudal, renaissance, post industrial, modern, or futuristic. Summarize a story using the Pixar method.  the story should take place in a few key concrete locations and involve both main characters and supporting roles. Half of the roles should be from a different country. If a role represents a group of people create a two or three representative individuals. Give each character a full name an age and description. Create a detailed description of this context including all locations, characters and a synopsis of how all of the story elements are related. "


STORY_CONTEXT=$(suffix_asset "$STORY_ASSET" "context")
openai_generate_completion_from_preamble_and_context "$STORY_CONTEXT_PREAMBLE" "$USER_PROVIDED_CONTEXT" "$STORY_CONTEXT"

CHARACTER_LIST_PREAMBLE="Given the following context if there are roles representing a group of people, create two or three representative characters from that group. create a list of all characters in the story in csv format where the first column is a unix filename based on the full name of the character with spaces converted into underscores and is prefixed with character and has a .json extension.  The second column is the full name of the character.  The third column is a brief description of the character's role in the story."
CHARACTER_LIST=$(sub_asset "$STORY_ASSET" "character_list")
openai_generate_completion_from_preamble_and_context "$CHARACTER_LIST_PREAMBLE" "$STORY_CONTEXT" "$CHARACTER_LIST"

CHARACTERS_ASSET=$(sub_asset "$STORY_ROOT_ASSET" characters)

CHARACTER_FILES=$(extract_column_from_list "$CHARACTER_LIST" 1 '.json')
for CHARACTER_FILE in $CHARACTER_FILES; do
    CHARACTER_FILE_PREFIX=$(basename "$CHARACTER_FILE" .json | tr 'A-Z' 'a-z')
    CHARACTER_ASSET=$(sub_asset "$CHARACTERS_ASSET" "$CHARACTER_FILE_PREFIX")

    CHARACTER_ROW=$(extract_rows_from_list "$CHARACTER_LIST" "$CHARACTER_FILE")
    if [ $? -ne 0 ]; then
        fatal "Could not find $CHARACTER_FILE in $CHARACTER_LIST"
    fi
    CHARACTER_NAME=`echo -n "$CHARACTER_ROW" | cut -f 2 -d,`

    if [ "X$DEBUG" == "X" ]; then
        info "Running $GENERATE_CHARACTER_SH"
        bash "$GENERATE_CHARACTER_SH" "$CHARACTER_ASSET" "$CHARACTER_NAME" "$STORY_CONTEXT"
    else
        info "Running $GENERATE_CHARACTER_SH in debug mode"
        bash -x "$GENERATE_CHARACTER_SH" "$CHARACTER_ASSET" "$CHARACTER_NAME" "$STORY_CONTEXT"
    fi
    if [ $? -ne 0 ]; then
        fatal "Could not create character $CHARACTER_ASSET"
    fi
done
