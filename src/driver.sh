#/usr/bin/env bash
set -euo pipefail

# These need to be set as evironment variables for this script.
PMFRGPATH="$(realpath "$PMFRGPATH")"
PROJECT="$(realpath "$PROJECT")"

ACTION=$1
CPUS_PER_TASK=${2:-76}
NTASKS_PER_NODE=${3:-1}

JULIASCRIPT="$PWD/src/slurm_benchmarking_MPI.jl"
SLURMSCRIPT="$PWD/src/slurm_benchmarking_MPI.sh"
MAIN_FUNCTIONS=(main 
	        check 
		check_head_and_tail)

#

main(){
	medium_loop medium_f_produce file_present_and_ok
	large_loop large_f_produce file_present_and_ok 
}

check(){
	medium_and_large_loops message_file_missing file_present_and_ok
}

check_head_and_tail(){
	medium_and_large_loops message_file_missing check_head_and_tail_single
}

rmfiles(){
	medium_and_large_loops rmfile rmfile
}

has_finished(){
	medium_and_large_loops message_file_missing check_job_finished

}

##

medium_loop(){
    F_NOT_EXIST="$1"
    F_EXIST="$2"
    for METHOD in DP5 VCABM
    do
        for NNODES in 1 2 4	
        do
            OUTFILENAME="$(get_outfilename "$NNODES" "$METHOD" "$CPUS_PER_TASK" "MEDIUM" "$NTASKS_PER_NODE")"
            JOBNAME="$(get_jobname "$NNODES" "$METHOD" "$CPUS_PER_TASK" "MEDIUM")"
            if does_not_exist_or_has_errors "$OUTFILENAME"
            then
	         "$F_NOT_EXIST" "$METHOD" "$NNODES" "$OUTFILENAME" "$JOBNAME"
	    else
                 "$F_EXIST" "$METHOD" "$NNODES" "$OUTFILENAME" "$JOBNAME"
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
            OUTFILENAME="$(get_outfilename "$NNODES" "$METHOD" "$CPUS_PER_TASK" "LARGE" "$NTASKS_PER_NODE")"
            JOBNAME="$(get_jobname "$NNODES" "$METHOD" "$CPUS_PER_TASK" "MEDIUM")"
            if does_not_exist_or_has_errors "$OUTFILENAME"
            then
	        "$F_NOT_EXIST" "$METHOD" "$NNODES" "$OUTFILENAME" "$JOBNAME"
	    else
	        "$F_EXIST" "$METHOD" "$NNODES" "$OUTFILENAME" "$JOBNAME"
	    fi
        done
    done
}


medium_and_large_loops(){
    F_NOT_EXIST="$1"
    F_EXIST="$2"

    medium_loop "$F_NOT_EXIST" "$F_EXIST"
    large_loop "$F_NOT_EXIST" "$F_EXIST"
}

###

medium_f_produce(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    local JOBNAME=$4
    echo "$OUTFILENAME needs to be produced"
    sbatch --output "$OUTFILENAME" --nodes="$NNODES" --job-name "$JOBNAME" \
	    "$SLURMSCRIPT" "$PROJECT" "$JULIASCRIPT" "$METHOD" "medium"
}


large_f_produce(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    local JOBNAME=$4
    echo "$OUTFILENAME needs to be produced"
    sbatch --output "$OUTFILENAME" --nodes="$NNODES" --job-name "$JOBNAME" -t 480 \
	    "$SLURMSCRIPT" "$PROJECT" "$JULIASCRIPT" "$METHOD" "large"
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

check_job_finished(){
    local METHOD=$1
    local NNODES=$2
    local OUTFILENAME=$3
    echo -n "$OUTFILENAME: "
    { grep -q "JOB FEEDBACK" "$OUTFILENAME" && echo "Job has finished" ; } || echo "Job has not finished" 
}
 
get_outfilename(){
    local NNODES="$1"
    local METHOD="$2"
    local CPUS_PER_TASK="$3"
    local PROBLEM="$4"
    local NTASKS_PER_NODE=${5:-1}
    local COMMIT="$(git -C "$PMFRGPATH" rev-parse HEAD)"
    local COMMIT_SHORTENED="${COMMIT:0:6}"

    echo "benchmark-${METHOD}-${NNODES}-${CPUS_PER_TASK}-${NTASKS_PER_NODE}-${PROBLEM}-${COMMIT_SHORTENED}-%j.out"

}

get_jobname(){
    local NNODES="$1"
    local METHOD="$2"
    local CPUS_PER_TASK="$3"
    local PROBLEM="$4"
    local NTASKS_PER_NODE=${5:-1}
    local COMMIT="$(git -C "$PMFRGPATH" rev-parse HEAD)"
    local COMMIT_SHORTENED="${COMMIT:0:3}"

    echo "${COMMIT_SHORTENED}_${METHOD:0:2}_${CPUS_PER_TASK}"

}

does_not_exist_or_has_errors(){
	local OUTFILENAME=$1
	ALLMATCHES=("${OUTFILENAME/\%j/*}")
	local FNAME="${ALLMATCHES[0]}"
	[ ! -f "$FNAME" ] || grep -q 'LoadError\|slurmstepd: error\|Segmentation fault\|Error: The Julia launcher' "$FNAME"
}




###########

"$ACTION"
