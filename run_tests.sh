#!/bin/bash

SCRIPT_DIR=`dirname $0`
BASH_DIR="$SCRIPT_DIR/bash"
if [ ! -d "$BASH_DIR" ]; then
    echo "Could not determine ltdt bash library directory" 1>&2
    exit -2
fi

. "$BASH_DIR/logging.sh"

TESTS_DIR="$SCRIPT_DIR/tests"
TEST_FILES=$(ls "$TESTS_DIR"/test_*.sh)
FAILURES=0
for TEST_FILE in $TEST_FILES; do
    bash "$TEST_FILE"
    if [ $? -ne 0 ]; then
        FAILURES=$(expr $FAILURES + 1)
    fi
done

if [ $FAILURES -eq 0 ]; then
    info "All suites passed"
else
    info "$FAILURES suites FAILED"
    exit $FAILURES
fi

