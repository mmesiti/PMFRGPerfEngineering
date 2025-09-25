#!/bin/bash
SEARCH_STRING="${1:-getDeriv}"


grep "$SEARCH_STRING" *out | tr ':' '\t' | sed 's/-/\t/g' |sed 's/.out//' | sed -E 's/\s+/\t/g'| sort -k5b,5.4 -k2b,2.4 -k6b,6.6 -k3n | uniq --check-chars=33 | cut -f2,3,5,6,8,9,10,11,12,13,14  
