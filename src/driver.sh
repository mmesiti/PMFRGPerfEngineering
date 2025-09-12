#!/usr/bin/env sh
SLURMSCRIPT="$PWD/src/slurm_benchmarking_MPI.sh"
JULIASCRIPT="$PWD/src/slurm_benchmarking_MPI.jl"

for METHOD in DP5 VCABM
do
    for NNODES in 1 2 4
    do
        "$SLURMSCRIPT" --nnodes="$NNODES" --cpus-per-task=76 "$JULIASCRIPT" "$METHOD" "medium"
    done
done


for METHOD in DP5 VCABM
do
    for NNODES in 1 2 4 8
    do
        "$SLURMSCRIPT" --nnodes="$NNODES" --cpus-per-task=76 "$JULIASCRIPT" "$METHOD" "large"
    done
done
