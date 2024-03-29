#!/bin/bash

FILE=$1
OUTPUT=$2

for execname in gnuindent gindent indent; do
  version=`$execname --version 2>/dev/null`
  if test "x$version" != "x"; then
    INDENT=$execname
    break
  fi
done

if test -z $INDENT; then
  echo "GStreamer git pre-commit hook:"
  echo "Did not find GNU indent, please install it before continuing."
  exit 1
fi

case `$INDENT --version` in
  GNU*)
      ;;
  default)
      echo "Did not find GNU indent, please install it before continuing."
      echo "(Found $INDENT, but it doesn't seem to be GNU indent)"
      exit 1
      ;;
esac

# Run twice. GNU indent isn't idempotent
# when run once
for i in 1 2; do
  if [ $i -eq 2 ]; then
    FILE=$OUTPUT
  fi
  $INDENT \
    --braces-on-if-line \
    --case-brace-indentation0 \
    --case-indentation2 \
    --braces-after-struct-decl-line \
    --line-length80 \
    --no-tabs \
    --cuddle-else \
    --dont-line-up-parentheses \
    --continuation-indentation4 \
    --honour-newlines \
    --tab-size8 \
    --indent-level2 \
    --leave-preprocessor-space \
    -o ${OUTPUT} \
    ${FILE}
done
