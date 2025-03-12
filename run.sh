#!/bin/sh

input=./sample.d/sample.dat

geninput(){
  echo generating input data...

  mkdir -p sample.d

  truncate -s 0 "${input}"

  printf '\0\0\x80\x3f' >> "${input}" # 1.0
  printf '\0\0\0\x40' >> "${input}"   # 2.0
  printf '\0\0\0\x3f' >> "${input}"   # 0.5
  printf '\0\0\x80\x3e' >> "${input}" # 0.25
}

geninput
xxd "${input}"

export ENV_FLOAT_DAT_NAME="${input}"
export ENV_MAX_FILE_SIZE=16777216

./FloatMeanMmap
