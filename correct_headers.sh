#!/bin/bash
    # GCC 6.1.1 has altered headers and QT5.7 triggers a bug when used with DJV.
    # We must instruct it to treat system include files as ordinary include files
find ./ -name 'includes_CXX.rsp' | while read fname; do
  echo "Correcting headers in ${fname}..."
  sed -i.bak 's/-isystem /-I/g' "${fname}"
  done
echo "Headers now corrected."
