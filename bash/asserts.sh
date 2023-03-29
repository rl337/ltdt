if [ "X$_X_ASSERTS_LIB_" == "X" ]; then
_X_ASSERTS_LIB_=true

. "$BASH_DIR/logging.sh"

# $1 = param 1
# $2 = param 2
# $3 = message
# fatal unless $1 == $2
assert_equal() {
    if [ "X$1" != "X$2" ]; then
        if [ "X$3" == "X" ]; then
            fatal "assert $1 == $2: FAIL"
        else
            fatal "assert $1 == $2: $3"
        fi
    fi
}

# $1 = param 1
# $2 = message
# fatal unless $1 == 0
assert_zero() {
    if [ $1 -ne 0 ]; then
        if [ "X$2" == "X" ]; then
            fatal "assert $1 == 0: FAIL"
        else 
            fatal "assert $1 == 0: $2"
        fi
    fi
}

# $1 = param 1
# $2 = message
# fatal unless $1 != 0
assert_not_zero() {
    if [ $1 -eq 0 ]; then
        if [ "X$2" == "X" ]; then
            fatal "assert $1 != 0: FAIL"
        else 
            fatal "assert $1 != 0: $2"
        fi
    fi
}

# $1 = haystack
# $2 = needle
# $3 = message
assert_string_match() {
    echo "$1" | grep -- "$2" > /dev/null
    assert_zero $? "Could not find $2 in $1"
}


# $1 = value to check for integerness
assert_valid_integer() {
    echo "$1" | grep -e '[^0-9]' > /dev/null
    if [ $? -eq 0 ]; then
        fatal "$1 is not an integer"
    fi
}


fi
