if [ "X$_X_PROMPT_MANAGEMENT_LIB_" == "X" ]; then
_X_PROMPT_MANAGEMENT_LIB_=true

if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"

# $1 file to append from
# $2 destination file
# $1 and $2 must not be the same file
catonate_prompt_files() {
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


# $1 prompt_string
# $2 destination file
create_prompt_file_from_string() {
    if [ -f "$2" ]; then
        info "prompt file already exists: $2"
        return
    fi

    echo -n "$1" | tr '\r\n\t' '   ' | sed -e 's/[ ][ ]*/ /g' | sed -e "s/\([0-9][0-9]*\)'[ ]*\([0-9][0-9]*\)\"/\1 ft \2 in/g"  > "$2"
    if [ $? -ne 0 ]; then
        fatal "Could not create prompt file: $1"
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
    catonate_prompt_files "$3" "$2"
}

fi
