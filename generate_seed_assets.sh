#!/bin/bash

SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/openai.sh"
. "$BASH_DIR/prompt_management.sh"

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

        
    extract_images_generations_response "$_TMP_RESPONSE_FILE" "$3"
}

# $1 original_context_file
# $2 new_context_name
# $3 new_context_file
# $4 preamble
refine_context_with_preamble() {
    if [ ! -f "$1" ]; then
        fatal "context file for $2 does not exist: $1"
    fi

    if [ -f "$3" ]; then
        info "context file for $2 already exists: $1"
    fi

    _X_NEW_CONTEXT_PROMPT_FILE="$SCRATCH_DIR/${2}_prompt.txt"
    prepend_preamble_to_prompt_file "$4" "$_X_NEW_CONTEXT_PROMPT_FILE" "$1"

    generate_completion_from_prompt "$_X_NEW_CONTEXT_PROMPT_FILE" "$2" "$3"
}


# $1 = character full name
# $2 = attribute_list_file
# $3 = portrait_file
# $4 = character_detail_file
# $5 = character_context_file
# $6 = output_file_name
write_character_sheet() {

_X_DETAILS=$(cat $4 | sed -e 's/\([&%$#_{}^\-]\)/\\\1/g')
_X_CONTEXT=$(cat $5 | sed -e 's/\([&%$#_{}^\-]\)/\\\1/g')

_X_ATTRIBUTE_LIST=$(cat $2 | sed -e 's/\([&%$#_{}^\-]\)/\\\1/g')
_X_AGE=$(echo -n "$_X_ATTRIBUTE_LIST" | grep 'Age' | cut -f2 -d,)
_X_SEX=$(echo -n "$_X_ATTRIBUTE_LIST" | grep 'Sex' | cut -f2 -d,)
_X_HAIR=$(echo -n "$_X_ATTRIBUTE_LIST" | grep 'Hair Color' | cut -f2 -d,)
_X_EYES=$(echo -n "$_X_ATTRIBUTE_LIST" | grep 'Eye Color' | cut -f2 -d,)
_X_BIRTHDATE=$(echo -n "$_X_ATTRIBUTE_LIST" | grep 'Birthdate' | cut -f2 -d,)
_X_ZODIAC=$(echo -n "$_X_ATTRIBUTE_LIST" | grep 'Zodiac Sign' | cut -f2 -d,)
_X_BLOOD=$(echo -n "$_X_ATTRIBUTE_LIST" | grep 'Blood Type' | cut -f2 -d,)
_X_BIRTHPLACE=$(echo -n "$_X_ATTRIBUTE_LIST" | grep 'Birth Place' | cut -f2- -d, | tr -d "\r\n")

_X_DATA=$(cat <<END
\documentclass{article}
\usepackage[letterpaper, total={7.5in, 10in}]{geometry}
\usepackage{multicol}
\usepackage{sectionbreak}
\usepackage{tabularx}
\usepackage{graphicx}
\graphicspath{{$SCRATCH_DIR/}}
\title{Character Dossier: $1}
\begin{document}


\begin{multicols}{2}

\section*{Character Dossier: $1}

\begin{center}
\includegraphics[width=3in,height=3in,natwidth=1024,natheight=1024]{$3}


\begin{tabularx}{3in}{|X X|} 
 \hline
 & \\\\
 Age & $_X_AGE \\\\
 Sex & $_X_SEX \\\\
 Hair & $_X_HAIR \\\\
 Eyes & $_X_EYES \\\\
 Birthdate & $_X_BIRTHDATE \\\\
 Zodiac Sign & $_X_ZODIAC \\\\
 Blood Type & $_X_BLOOD \\\\
 Birthplace & $_X_BIRTHPLACE \\\\
 & \\\\
 \hline
\end{tabularx}

\end{center}

\sectionbreak

\section*{Physical Description}
$_X_DETAILS

\section*{Character Overview}
$_X_CONTEXT


\end{multicols}
\end{document}
END
)

CHARACTER_TEX_FILE="$SCRATCH_DIR/$6.tex"
echo "$_X_DATA" > "$CHARACTER_TEX_FILE"
latex -output-directory="$SCRATCH_DIR" -output-format=dvi "$CHARACTER_TEX_FILE"
if [ $? -ne 0 ]; then
    fatal "Could not run latex on $CHARACTER_TEX_FILE"
fi

CHARACTER_DVI_FILE="$SCRATCH_DIR/$6.dvi"
CHARACTER_PDF_FILE="$SCRATCH_DIR/$6.pdf"
dvipdfm "$CHARACTER_DVI_FILE" -o "$CHARACTER_PDF_FILE"

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

USER_PROVIDED_PROMPT_FILE="$SCRATCH_DIR/original_prompt.txt"
if [ ! -f "$USER_PROVIDED_PROMPT_FILE" ]; then
    # record and store the original user prompt
    create_prompt_file_from_string "$2" "$USER_PROVIDED_PROMPT_FILE"
    info "Using initial prompt: $2"
else
    info "User provided prompt file already exists: $USER_PROVIDED_PROMPT_FILE"
fi


STORY_PROMPT_PREAMBLE="Given the following prompt, if not already specified choose a setting from an arbitrary selection of top 25 countries by GDP other than the United States. If not already specified, choose an arbitrary time period for the story.  valid time periods are prehistoric, feudal, renaissance, post industrial, modern, or futuristic. Summarize a story using the Pixar method.  the story should take place in a few key concrete locations and involve both main characters and supporting roles. Half of the roles should be from a different country. If a role represents a group of people create a two or three representative individuals. Give each character a full name an age and description. Create a detailed description of this context including all locations, characters and a synopsis of how all of the story elements are related. "
STORY_CONTEXT_FILE="$SCRATCH_DIR/story_context.txt"

info "Creating story context"
refine_context_with_preamble "$USER_PROVIDED_PROMPT_FILE" story_context "$STORY_CONTEXT_FILE" "$STORY_PROMPT_PREAMBLE"

CHARACTER_LIST_PREAMBLE="Given the following context if there are roles representing a group of people, create two or three representative characters from that group. Give each character a full name, age, sex, hair color, eye color, birth date, a zodiac sign consistent with their birth date, blood type, birth place,  and description. create a list of all characters in the story in csv format where the first column is a unix filename based on the name of the character with spaces converted into underscores and is prefixed with character and has a .json extension.  The second column is the full name of the character.  The third column is a brief description of the character's role in the story."
CHARACTER_LIST_CSV="$SCRATCH_DIR/character_list.csv"

info "Creating character list"
refine_context_with_preamble "$STORY_CONTEXT_FILE" character_list "$CHARACTER_LIST_CSV" "$CHARACTER_LIST_PREAMBLE"

CHARACTER_FILES=`cat "$CHARACTER_LIST_CSV" | grep '.json' | cut -f 1 -d,`
for CHARACTER_FILE in $CHARACTER_FILES; do
    CHARACTER_FILE_PREFIX=`basename "$CHARACTER_FILE" .json`

    CHARACTER_ROW=`cat "$CHARACTER_LIST_CSV" | grep $CHARACTER_FILE`
    if [ $? -ne 0 ]; then
        fatal "Could not find $CHARACTER_FILE in $CHARACTER_LIST_RESPONSE_FILE"
    fi
    CHARACTER_NAME=`echo -n "$CHARACTER_ROW" | cut -f 2 -d,`

    info "Creating character: $CHARACTER_NAME"

    CHARACTER_CONTEXT_NAME="${CHARACTER_FILE_PREFIX}_context"
    CHARACTER_CONTEXT_PREAMBLE="given the following context describe the character $CHARACTER_NAME, their motivations their life before the story and their role in the story details should also include age, sex, hair color, eye color, birth date, a zodiac sign consistent with their birth date, blood type and birth place. If their place of birth is not in the setting of the story, describe why they left their birth place"
    CHARACTER_CONTEXT_FILE="$SCRATCH_DIR/${CHARACTER_CONTEXT_NAME}.txt"
    refine_context_with_preamble "$STORY_CONTEXT_FILE" "$CHARACTER_CONTEXT_NAME" "$CHARACTER_CONTEXT_FILE" "$CHARACTER_CONTEXT_PREAMBLE"

    CHARACTER_ATTRIBUTES_NAME="${CHARACTER_FILE_PREFIX}_attributes"
    CHARACTER_ATTRIBUTES_PREAMBLE="given the following character information create a list of character attributes in csv format list where the first column is the name of an attribute and the second column is the value based on the character description. The rows are name, age, sex, hair color, eye color, birthdate, zodiac sign, blood type, and birth place."
    CHARACTER_ATTRIBUTES_CSV="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_attributes.csv"
    refine_context_with_preamble "$CHARACTER_CONTEXT_FILE" "$CHARACTER_ATTRIBUTES_NAME" "$CHARACTER_ATTRIBUTES_CSV" "$CHARACTER_ATTRIBUTES_PREAMBLE"

    CHARACTER_DETAIL_NAME="${CHARACTER_FILE_PREFIX}_detail"
    CHARACTER_DETAIL_PREAMBLE="given the following context describe the character $CHARACTER_NAME create a detailed physical description of the character including physical features that make them stand out as well as any possessions they will always have on themselves.  The description should also include clothing preferences. "
    CHARACTER_DETAIL_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_detail.txt"
    refine_context_with_preamble "$CHARACTER_CONTEXT_FILE" "$CHARACTER_DETAIL_NAME" "$CHARACTER_DETAIL_FILE" "$CHARACTER_DETAIL_PREAMBLE"

    CHARACTER_PORTRAIT_CONTEXT_NAME="${CHARACTER_FILE_PREFIX}_portrait_context"
    CHARACTER_PORTRAIT_CONTEXT_PREAMBLE="write a DALL-E prompt for a portrait of the following person that is no longer than 900 characters long. "
    CHARACTER_PORTRAIT_CONTEXT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_portrait_context.txt"
    refine_context_with_preamble "$CHARACTER_DETAIL_FILE" "$CHARACTER_PORTRAIT_CONTEXT_NAME" "$CHARACTER_PORTRAIT_CONTEXT_FILE" "$CHARACTER_PORTRAIT_CONTEXT_PREAMBLE"

    CHARACTER_PORTRAIT_PREAMBLE="take a photographic portrait with a 35mm lens of the following character"
    CHARACTER_PORTRAIT_SUFFIX="35mm, fujifilm, dramatic lighting, cinematic, 4k"
    CHARACTER_PORTRAIT_PROMPT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_portrait_prompt.txt"
    prepend_preamble_to_prompt_file "$CHARACTER_PORTRAIT_PREAMBLE" "$CHARACTER_PORTRAIT_PROMPT_FILE" "$CHARACTER_PORTRAIT_CONTEXT_FILE"
    append_string_to_prompt_file "$CHARACTER_PORTRAIT_SUFFIX" "$CHARACTER_PORTRAIT_PROMPT_FILE"
    CHARACTER_PORTRAIT_FILE="$SCRATCH_DIR/${CHARACTER_FILE_PREFIX}_portrait.jpg"
    generate_image_from_prompt "$CHARACTER_PORTRAIT_PROMPT_FILE" "${CHARACTER_FILE_PREFIX}_portrait" "$CHARACTER_PORTRAIT_FILE"

    CHARACTER_DOSSIER_NAME="${CHARACTER_FILE_PREFIX}_dossier"
    write_character_sheet "$CHARACTER_NAME" "$CHARACTER_ATTRIBUTES_CSV" "$CHARACTER_PORTRAIT_FILE" "$CHARACTER_DETAIL_FILE" "$CHARACTER_CONTEXT_FILE" "$CHARACTER_DOSSIER_NAME"
done
