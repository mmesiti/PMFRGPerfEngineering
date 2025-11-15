#!/bin/bash
SEARCH_STRING="${1:-getDeriv!}"

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

get_starttime(){
	FILENAME="$1"
	grep 'Starttime: ' $FILENAME | sed 's/Starttime: //'
}

get_nodelist(){
	FILENAME="$1"
	local NLIST=$(grep 'Nodelist: ' $FILENAME | sed 's/Nodelist: //')
	printf "\"%20.20s\"" $NLIST

}


for FILE in *.out
do 
	#echo $(process_filename "$FILE") $(get_starttime "$FILE") $(get_nodelist "$FILE") $(get_value "$FILE")
	echo $(process_filename "$FILE") $(get_starttime "$FILE") $(get_value "$FILE")
done | sed -E 's/\s+/\t/g' \
	| sed 's/208be3/PA/;
	       s/4c9e26/master/;
	       s/f5477e/SSA/;
	       s/fc04e5/GXBLB/;
	       s/613900/SSATS/;
	       s/150e9e/MSTTS/;
	       s/b6f16d/PATS/;
	       s/03b0a8/MSTPI/;
	       s/e36f46/PAPI/;' \
	| sort -k5,5.5 -k1,1.3 -k2n -k3n -k6,6.3
