#!/bin/bash
#SBATCH --partition cpuonly
#SBATCH --time 15
#SBATCH --ntasks-per-node 1
#SBATCH --cpus-per-task=76
#SBATCH --exclusive
#SBATCH --dependency singleton
#SBATCH --job-name pmfrg-benchmark

PROJECT="$PWD"

set -o nounset
module use "$HOME/modules"
# This is needed anyway by mpiexecjl,
# and needs to match the content of $PROJECT/LocalPreferences.toml
# (as set by MPIPreferences.jl).
module load mpi/openmpi/4.1 
module load julia/juliaup
export ZES_ENABLE_SYSMAN=1
export OMPI_MCA_coll_hcoll_enable="0"
export UCX_ERROR_SIGNALS="SIGILL,SIGBUS,SIGFPE"

MPIEXEC="$HOME/.julia/bin/mpiexecjl --project=$PROJECT"

# This file - unfortunately with sbatch the trick ${BASH_SOURCE[0]} does not work.
SCRIPT="$(realpath "$1")"

echo "Julia version:"
julia +1.11.6 --version

COMMAND=("$MPIEXEC" -n "$SLURM_NTASKS"
         julia +1.11.6 --project="$PROJECT" 
         --optimize=3 
         --threads "$SLURM_CPUS_PER_TASK"
	 "$SCRIPT")
echo "${COMMAND[@]}"
"${COMMAND[@]}"
