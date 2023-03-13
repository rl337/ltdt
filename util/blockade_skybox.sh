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
    fatal "Usage: $0 <prompt_string> <negative_prompt_string> <output_file>"
}


if [ "X$1" == "X" ]; then
    usage
fi

if [ "X$2" == "X" ]; then
    usage
fi

if [ "X$3" == "X" ]; then
    usage
fi

stable_skybox "$1" "$2" > /tmp/response.json
REQUEST_ID=$(cat /tmp/response.json | jq -e -r .request.id)
if [ $? -ne 0 ]; then
    fatal "Could not get response id"
fi

CURRENT_PROGRESS=$(request_status "$REQUEST_ID" | jq .request.progress)
while [ $CURRENT_PROGRESS -lt 100 ]; do
    sleep 30
    CURRENT_PROGRESS=$(request_status "$REQUEST_ID" | jq .request.progress)
done

request_status "$REQUEST_ID" > /tmp/response_final.json
CURRENT_STATUS=$(cat /tmp/response_final.json | jq -r .request.status)
if [ $? -ne 0 ]; then
    fatal "Could not extract status from last response"
fi
if [ "X$CURRENT_STATUS" != "Xcomplete" ]; then
    fatal "Unexpected status for request $REQUEST_ID: $CURRENT_STATUS"
fi

FILE_URL=$(cat /tmp/response_final.json | jq -r .request.file_url)
if [ $? -ne 0 ]; then
    fatal "Could not extract file_url from last response"
fi
if [ "X$FILE_URL" == "X" ]; then
    fatal "Got an empty file url from last response"
fi

curl "$FILE_URL" > "$3"
