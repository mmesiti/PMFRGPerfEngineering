#!/usr/bin/env sh
JULIASCRIPT="$PWD/src/slurm_benchmarking_MPI.jl"
SLURMSCRIPT="$PWD/src/slurm_benchmarking_MPI.sh"
PMFRGPATH="$(realpath "$PWD/../PMFRG.jl")"

set -euo pipefail

MAIN_FUNCTIONS=(main 
	        check 
		check_head_and_tail)

#

main(){
	medium_loop medium_f_produce file_present_and_ok
	large_loop large_f_produce file_present_and_ok 
}

check(){
	medium_loop message_file_missing file_present_and_ok
	large_loop message_file_missing file_present_and_ok
}

check_head_and_tail(){
	medium_loop message_file_missing check_head_and_tail_single
	large_loop message_file_missing check_head_and_tail_single
}

rmfiles(){
	medium_loop rmfile rmfile
	large_loop rmfile rmfile 
}


##
medium_loop(){
    F_NOT_EXIST="$1"
    F_EXIST="$2"
    for METHOD in DP5 VCABM
    do
        for NNODES in 1 2 4	
        do
            OUTFILENAME="$(get_outfilename "$NNODES" "$METHOD" "76" "MEDIUM")"
            if does_not_exist_or_has_errors "$OUTFILENAME"
            then
	         "$F_NOT_EXIST" "$METHOD" "$NNODES" "$OUTFILENAME"
	    else
                 "$F_EXIST" "$METHOD" "$NNODES" "$OUTFILENAME"
	    fi
        done
    done
}

large_loop(){
    F_NOT_EXIST="$1"
    F_EXIST="$2"
    for METHOD in DP5 VCABM 
    do
        for NNODES in 1 2 4 8  
        do
            OUTFILENAME="$(get_outfilename "$NNODES" "$METHOD" "76" "LARGE")"
            if does_not_exist_or_has_errors "$OUTFILENAME"
            then
	        "$F_NOT_EXIST" "$METHOD" "$NNODES" "$OUTFILENAME"
	    else
	        "$F_EXIST" "$METHOD" "$NNODES" "$OUTFILENAME"
	    fi
        done
    done
}

###

medium_f_produce(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    echo "$OUTFILENAME needs to be produced"
    sbatch --output "$OUTFILENAME" --nodes="$NNODES" --cpus-per-task=76 "$SLURMSCRIPT" "$JULIASCRIPT" "$METHOD" "medium"
}


large_f_produce(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    echo "$OUTFILENAME needs to be produced"
    sbatch --output "$OUTFILENAME" --nodes="$NNODES" -t 240 --cpus-per-task=76 "$SLURMSCRIPT" "$JULIASCRIPT" "$METHOD" "large"
}


file_present_and_ok(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    echo "File $OUTFILENAME exists and contains no error"
}

message_file_missing(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    echo "Either $OUTFILENAME does not exists or contains errors."
}

check_head_and_tail_single(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    echo "======================="
    echo "$OUTFILENAME"
    echo "======================="
    echo "== HEAD ==============="
    echo "======================="
    head "$OUTFILENAME"
    echo "======================="
    echo "== TAIL ==============="
    echo "======================="

    REAL_OUTPUT_LENGTH=$( { grep -n  "JOB FEEDBACK" "$OUTFILENAME" | cut -d: -f 1; } || { cat $OUTFILENAME | wc -l ; } )
    head -n "$REAL_OUTPUT_LENGTH" "$OUTFILENAME" | tail
    echo "======================="
}
rmfile(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    echo "Moving $OUTFILENAME to thrash..."
    mkdir -p thrash_can
    mv "$OUTFILENAME" thrash_can
}


get_outfilename(){
    NNODES="$1"
    METHOD="$2"
    CPUS_PER_TASK="$3"
    PROBLEM="$4"
    COMMIT="$(git -C "$PMFRGPATH" rev-parse HEAD)"
    COMMIT_SHORTENED="${COMMIT:0:6}"

    echo "benchmark-${METHOD}-${NNODES}-${CPUS_PER_TASK}-${PROBLEM}-${COMMIT_SHORTENED}.out"

}

does_not_exist_or_has_errors(){
	local OUTFILENAME=$1
	[ ! -f "$OUTFILENAME" ] || grep -q 'LoadError\|slurmstepd: error\|Segmentation fault\|Error: The Julia launcher' "$OUTFILENAME"
}

###########

"$1"
