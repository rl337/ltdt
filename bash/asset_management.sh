if [ "X$_X_ASSET_MANAGEMENT_LIB_" == "X" ]; then
_X_ASSET_MANAGEMENT_LIB_=true

if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"

if [ "X$ROOT_ASSET" == "X" ]; then
    ROOT_ASSET="story"
fi

root_asset() {
    echo -n "$ROOT_ASSET"
}

# $1 = asset_id
assert_valid_asset() {
    echo "$1" | grep -e '[^a-z0-9_/]' > /dev/null
    if [ $? -eq 0 ]; then
        fatal "$1 is not a valid asset_id.  Must be a '/' separated list of [a-z0-9_]+"
    fi

    echo "$1" | grep -e '^[^a-z]' > /dev/null
    if [ $? -eq 0 ]; then
        fatal "$1 is not a valid asset_id.  Must be a start with a [a-z]"
    fi

    echo "$1" | grep '^/' > /dev/null
    if [ $? -eq 0 ]; then
        fatal "$1 is not a valid asset_id.  Must not begin with a '/'"
    fi

    echo "$1" | grep '[a-z0-9_]$' > /dev/null
    if [ $? -ne 0 ]; then
        fatal "$1 is not a valid asset_id.  Must end with a [a-z0-9_]"
    fi
}

# $1 = value to check for integerness
assert_valid_integer() {
    echo "$1" | grep -e '[^0-9]' > /dev/null
    if [ $? -eq 0 ]; then
        fatal "$1 is not an integer"
    fi
}

assert_valid_asset_root() {
    if [ "X$ASSET_ROOT" == "X" ]; then
        fatal "ASSET_ROOT must be set"
    fi

    if [ ! -d "$ASSET_ROOT" ]; then
        fatal "Asset root $ASSET_ROOT must be a valid directory"
    fi
}

# $1 = parent asset_id
# $2 = sub asset_name
# basically echos $1/$2
sub_asset() {
    _X_SUB_ASSET="$1/$2"
    assert_valid_asset "$_X_SUB_ASSET"
    echo -n "$_X_SUB_ASSET"
}

# $1 = original asset_id
# $2 = string to append to original asset name
# basically echos $1_$2
suffix_asset() {
    _X_NEW_ASSET="${1}_${2}"
    assert_valid_asset "$_X_NEW_ASSET"
    echo -n "$_X_NEW_ASSET"
}

# $1 = asset_id
parent_asset() {
    assert_valid_asset "$1"

    if [ "X$1" == "X$ROOT_ASSET" ]; then
        fatal "Root asset $1 has no parent"
    fi

    dirname "$1"
}

# $1 = asset_id to get path for
asset_path() {
    assert_valid_asset_root
    assert_valid_asset "$1"

    case "$1" in
        *_prompt) echo -n "$ASSET_ROOT/$1.prompt" ;;
        *_context) echo -n "$ASSET_ROOT/$1.context" ;;
        *_response) echo -n "$ASSET_ROOT/$1.json" ;;
        *_portrait) echo -n "$ASSET_ROOT/$1.jpg" ;;
        *_image) echo -n "$ASSET_ROOT/$1.jpg" ;;
        *_skybox) echo -n "$ASSET_ROOT/$1.jpg" ;;
        *_list) echo -n "$ASSET_ROOT/$1.csv" ;;
        *_base64) echo -n "$ASSET_ROOT/$1.base64" ;;
        *) echo -n "$ASSET_ROOT/$1"
    esac
}

# $1 = asset_id to check if exists as file
file_exists() {
    assert_valid_asset "$1"
    
    [ -f $(asset_path "$1") ]
}

# $1 = asset_id to check if asset does not exist as a file or directory
asset_missing() {
    assert_valid_asset "$1"
    
    [ ! -e $(asset_path "$1") ]
}

# $1 = asset_id to check if exists as directory
directory_exists() {
    assert_valid_asset "$1"
    
    [ -d $(asset_path "$1") ]
}

# $1 = asset_id asserting is a file
assert_asset_missing() {
    assert_valid_asset "$1"

    asset_missing "$1"
    if [ $? -ne 0 ]; then
        fatal "Expected asset to NOT exist $1 ($(asset_path $1))"
    fi
}

# $1 = asset_id asserting is a file
assert_file_exists() {
    assert_valid_asset "$1"

    file_exists "$1"
    if [ $? -ne 0 ]; then
        fatal "Expected asset to exist as a file $1 ($(asset_path $1))"
    fi
}

# $1 = asset_id asserting is a directory
assert_directory_exists() {
    assert_valid_asset "$1"

    directory_exists "$1"
    if [ $? -ne 0 ]; then
        fatal "Expected asset to exist as a directory $1 ($(asset_path $1))"
    fi
}

# $1 = asset_id of directory that needs to exist
ensure_asset_directory() {
    assert_valid_asset_root
    assert_valid_asset "$1"

    _X_ASSET_PATH=$(asset_path "$1")
    mkdir -p "$_X_ASSET_PATH"
    if [ $? -ne 0 ]; then
        fatal "Could not create directory for $_X_ASSET_PATH"
    fi
}

# $1 = asset_id whose parent needs to exist
ensure_parent_asset_directory() {
    assert_valid_asset_root
    assert_valid_asset "$1"
    _X_PARENT_ASSET=$(parent_asset "$1")
    ensure_asset_directory "$_X_PARENT_ASSET"
}


# $1 asset_id to test
assert_is_context() {
    assert_valid_asset "$1"
    echo -n "$1" | grep '_context$' > /dev/null
    if [ $? -ne 0 ]; then
        fatal "$1 is not a context asset"
    fi
}

# $1 asset_id to test
assert_is_prompt() {
    assert_valid_asset "$1"
    echo -n "$1" | grep '_prompt$' > /dev/null
    if [ $? -ne 0 ]; then
        fatal "$1 is not a prompt asset"
    fi
}

# $1 asset_id to test
assert_is_list() {
    assert_valid_asset "$1"
    echo -n "$1" | grep '_list$' > /dev/null
    if [ $? -ne 0 ]; then
        fatal "$1 is not a list asset"
    fi
}


# $1 = list asset_id
# $2 = optional regex match
extract_rows_from_list() {
    assert_is_list "$1"
    assert_file_exists "$1"

    _X_CSV_FILE=$(asset_path "$1")
    if [ "X$2" == "X" ]; then
        cat "$_X_CSV_FILE"
    else
        cat "$_X_CSV_FILE" | grep -e "$2"
    fi
}

# $1 = list asset_id
# $2 = column number to extract
# $3 = optional regex filter
extract_column_from_list() {
    assert_is_list "$1"
    assert_file_exists "$1"

    assert_valid_integer "$2"

    _X_CSV_FILE=$(asset_path "$1")
    if [ "X$3" == "X" ]; then
        cat "$_X_CSV_FILE" | cut -f "$2" -d,
    else
        cat "$_X_CSV_FILE" | cut -f "$2" -d, | grep "$3"
    fi
}



# $1 source asset_id
# $2 destination asset_id
# $1 and $2 must not be the asset
catonate_contexts() {
    assert_is_context "$1"
    _X_PATH_1=$(asset_path "$1")
    if [ ! -f "$_X_PATH_1" ]; then
        fatal "file to append from does not exist: $1 ($_X_PATH_1)"
    fi

    assert_is_context "$2"
    _X_PATH_2=$(asset_path "$2")
    if [ ! -f "$_X_PATH_2" ]; then
        fatal "file to append to does not exist: $2 ($_X_PATH_2)"
    fi

    cat "$_X_PATH_1" | tr '\r\n\t' '   ' | sed -e 's/[ ][ ]*/ /g' | sed -e "s/\([0-9][0-9]*\)'[ ]*\([0-9][0-9]*\)\"/\1 ft \2 in/g" >> "$_X_PATH_2"
    if [ $? -ne 0 ]; then
        fatal "Could not append $_X_PATH_1 to $_X_PATH_2"
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

# $1 string to filter
filter_prompt_string() {
    echo -n "$1" | tr '\r\n\t' '   ' | sed -e 's/[ ][ ]*/ /g' | sed -e "s/\([0-9][0-9]*\)'[ ]*\([0-9][0-9]*\)\"/\1 ft \2 in/g" 
}

# $1 string
# $2 destination asset_id
create_asset_from_string() {
    assert_valid_asset "$2"

    directory_exists "$2"
    assert_not_zero $? "$2 already exists as a directory asset"

    file_exists "$2"
    assert_not_zero $? "$2 already exists, cannot create"

    ensure_parent_asset_directory "$2"
    _X_ASSET_FILE=$(asset_path "$2")
    echo "$1" > "$_X_ASSET_FILE"
    if [ $? -ne 0 ]; then
        fatal "Could not create asset: $2 ($_X_ASSET_FILE)"
    fi
}


# $1 context_string
# $2 destination asset_id
create_context_from_string() {
    assert_is_context "$2"

    file_exists "$2"
    if [ $? -eq 0 ]; then
        info "context exists: $2 ($(asset_path $2))"
        return
    fi

    create_asset_from_string "$1" "$2"
}

# $1 prompt_string
# $2 destination asset_id
create_prompt_from_string() {
    assert_is_prompt "$2"

    file_exists "$2"
    if [ $? -eq 0 ]; then
        info "prompt exists: $2"
        return
    fi

    create_asset_from_string $(filter_prompt_string "$1") "$2"
}

# $1 prompt asset_id
# $2 preamble_string
# $3 context asset_id
# $4 optional suffix_string
create_prompt_from_preamble_and_context() {
    assert_is_prompt "$1"
    assert_is_context "$3"

    if [ "X$2" == "X" ]; then
        fatal "preamble cannot be empty"
    fi

    create_prompt_from_string "$2" "$1"
    
    _X_CONTEXT_FILE=$(asset_path "$3")
    _X_CONTEXT=$(cat $_X_CONTEXT_FILE)

    _X_PROMPT_FILE=$(asset_path "$1")
    filter_prompt_string "$_X_CONTEXT" >> "$_X_PROMPT_FILE"

    if [ "X$4" != "X" ]; then
        filter_prompt_string "$4" >> "$_X_PROMPT_FILE"
    fi
}

# $1 preamble
# $2 destination file
# $3 file to append to preamble
prepend_preamble_to_prompt_file() {
    if [ -f "$2" ]; then
        info "prompt file already exists: $2"
        return
    fi

    create_prompt_file_from_string "$1" "$2"
    catonate_contexts "$3" "$2"
}

fi
