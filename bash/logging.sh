

if [ "X$_X_LOGGING_LIB_" == "X" ]; then
_X_LOGGING_LIB_=true

mesg() {
    _X_PREFIX=`date`

    echo "$_X_PREFIX $*" 1>&2
}

debug() {
    if [ "X$DEBUG" != "X" ]; then
        mesg "DEBUG $*"
    fi
}

info() {
    mesg "INFO $*"
}

fatal() {
    mesg "FATAL $*"
    exit -1
}

fi
