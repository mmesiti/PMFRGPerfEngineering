#!/bin/bash
SEARCH_STRING="${1:-getDeriv}"



process_filename(){
	FILENAME="$1"
	echo "$FILENAME" |sed 's/.out//;s/benchmark-//g' | sed 's/-/\t/g' 
}
get_value(){
	FILENAME="$1"
        if grep -q "$SEARCH_STRING" "$FILENAME"
	then 	
            grep "$SEARCH_STRING" "$FILENAME" | head -n 1
	else
            if grep -q "DUE TO TIME LIMIT" "$FILENAME"
	    then 
		    echo "$SEARCH_STRING" "TIME_LIMIT_REACHED"
            else
		    echo "$SEARCH_STRING" "Unknown_problems"
	    fi

	fi
}

for FILE in *.out
do 
	echo $(process_filename "$FILE") $(get_value "$FILE")
done | sed -E 's/\s+/\t/g' \
	| sed 's/208be3/PA/;s/4c9e26/master/;s/f5477e/SSA/;s/fc04e5/GXBLB/' \
	| sort -k4b,4.4 -k1b,1.4 -k2n -k5b,4.6  \
