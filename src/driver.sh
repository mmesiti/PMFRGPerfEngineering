#!/usr/bin/env sh
set -x
SLURMSCRIPT="$PWD/src/slurm_benchmarking_MPI.sh"
JULIASCRIPT="$PWD/src/slurm_benchmarking_MPI.jl"
PMFRGPATH="$(realpath "$PWD/../PMFRG.jl")"

set -eu

get_outfilename(){
    NNODES="$1"
    METHOD="$2"
    CPUS_PER_TASK="$3"
    PROBLEM="$4"
    COMMIT="$(git -C "$PMFRGPATH" rev-parse HEAD)"
    COMMIT_SHORTENED="${COMMIT:0:6}"

    echo "benchmark-${METHOD}-${NNODES}-${CPUS_PER_TASK}-${PROBLEM}-${COMMIT_SHORTENED}.out"

}

for METHOD in DP5 VCABM
do
    for NNODES in 1 2 4
    do
        OUTFILENAME=$(get_outfilename "$NNODES" "$METHOD" "76" "MEDIUM")
        sbatch --output "$OUTFILENAME" --nodes="$NNODES" --cpus-per-task=76 "$SLURMSCRIPT" "$JULIASCRIPT" "$METHOD" "medium"
    done
done


for METHOD in DP5 VCABM
do
    for NNODES in 1 2 4 8
    do
        OUTFILENAME=$(get_outfilename "$NNODES" "$METHOD" "76" "LARGE")
        sbatch --output "$OUTFILENAME"  --nodes="$NNODES" --cpus-per-task=76  "$SLURMSCRIPT" "$JULIASCRIPT" "$METHOD" "large"
    done
done
