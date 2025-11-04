#!/bin/bash
#SBATCH --partition cpuonly
#SBATCH --time 15
#SBATCH --ntasks-per-node 1
#SBATCH --cpus-per-task=76
#SBATCH --exclusive
#SBATCH --job-name pmfrg-benchmark

PROJECT="$1"
shift

set -o nounset
module purge
module use "$HOME/modules"
# This is needed anyway by mpiexecjl,
# and needs to match the content of $PROJECT/LocalPreferences.toml
# (as set by MPIPreferences.jl).
module load julia/juliaup

# Host's OPENMPI
module load compiler/gnu
module load mpi/openmpi
# Variables Needed to use openmpi
export ZES_ENABLE_SYSMAN=1
export OMPI_MCA_coll_hcoll_enable="0"
export UCX_ERROR_SIGNALS="SIGILL,SIGBUS,SIGFPE"

MPIEXEC="$HOME/.julia/bin/mpiexecjl"

SCRIPT="$(realpath "$1")"
shift

echo "Julia version:"
julia --version

COMMAND=("$MPIEXEC" --project="$PROJECT" 
	 -n "$SLURM_NTASKS"
         julia --project="$PROJECT" 
         --optimize=3 
         --threads "$SLURM_CPUS_PER_TASK"
	 "$SCRIPT" "$@")
echo "${COMMAND[@]}"
"${COMMAND[@]}"
