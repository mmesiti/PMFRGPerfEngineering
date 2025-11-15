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
# Obsolete when using system mpirun
# # This is needed anyway by mpiexecjl,
# # and needs to match the content of $PROJECT/LocalPreferences.toml
# # (as set by MPIPreferences.jl).
# module load julia/juliaup
# Host's OPENMPI
module load compiler/gnu
module load mpi/openmpi
# Variables Needed to use openmpi
export ZES_ENABLE_SYSMAN=1
export OMPI_MCA_coll_hcoll_enable="0"
export UCX_ERROR_SIGNALS="SIGILL,SIGBUS,SIGFPE"

# Obsolete when using system mpirun
# MPIEXEC="$HOME/.julia/bin/mpiexecjl"

SCRIPT="$(realpath "$1")"
CPUINFO_SCRIPT="$(dirname "$SCRIPT")"/print_cpuinfo.sh
shift

echo "Julia version:"
julia --version

# Optional when using system mpirun
# # We need to cd into project 
# # otherwise the wrong mpiexec will be choosen.
# # This might be the cause of flaky performance
# # (e.g., some runs happening in 3 hours or in 1)
cd "$PROJECT"

COMMAND=(mpirun) # using system's mpirun for consistency


if [ 2 -eq "$SLURM_NTASKS_PER_NODE" ]
then

COMMAND+=(--map-by ppr:1:package # This makes sense only with more than one process per node
          --bind-to package)
fi	 

COMMAND+=(-n "$SLURM_NTASKS"
	 --display-map
	 --display-allocation
         julia --project=.
         --optimize=3 
         --threads "$SLURM_CPUS_PER_TASK"
	 "$SCRIPT" "$@")

srun --ntasks-per-node=1 "$CPUINFO_SCRIPT"
	 
echo "${COMMAND[@]}"
"${COMMAND[@]}"
