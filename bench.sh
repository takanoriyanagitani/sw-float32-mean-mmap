#!/bin/sh

input=./sample.d/heavy.dat

geninput(){
  echo generating input data...

  dd \
    if=/dev/zero \
    of="${input}" \
    bs=1048576 \
    count=1024 \
    status=progress
}

test -f "${input}" || geninput

export ENV_FLOAT_DAT_NAME="${input}"
export ENV_MAX_FILE_SIZE=$(( 2048 * 1048576 ))

\time -l ./FloatMeanMmap
