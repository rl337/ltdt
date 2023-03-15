#!/bin/bash

SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/../bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"
. "$BASH_DIR/asset_management.sh"
. "$BASH_DIR/blockade.sh"

usage() {
    fatal "Usage: $0 <prompt_string> <output_asset>"
}

if [ "X$1" == "X" ]; then
    usage
fi

if [ "X$2" == "X" ]; then
    usage
fi

if [ "X$ASSET_ROOT" == "X" ]; then
    fatal "You must set an ASSET_ROOT"
fi


ROOT_ASSET=$(root_asset)
SCRATCH_ASSET=$(sub_asset "$ROOT_ASSET" "scratch")

assert_valid_asset "$2"
OUTPUT_ASSET=$(sub_asset "$SCRATCH_ASSET" "$2")
OUTPUT_IMAGE_ASSET=$(suffix_asset "$OUTPUT_ASSET" "skybox")
OUTPUT_ASSET_PROMPT=$(suffix_asset "$OUTPUT_IMAGE_ASSET" "prompt")
create_prompt_from_string "$1" "$OUTPUT_ASSET_PROMPT"

generate_skybox_from_prompt "$OUTPUT_ASSET_PROMPT" "$OUTPUT_IMAGE_ASSET"
