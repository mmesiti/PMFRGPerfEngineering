#!/bin/bash
#=
#SBATCH --partition cpuonly
#SBATCH --time 1440
#SBATCH --nodes 1
#SBATCH --ntasks-per-node 1
#SBATCH --cpus-per-task=76
#SBATCH --exclusive
#SBATCH --job-name pmfrg-benchmark-1

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
SCRIPT="$PROJECT/src/slurm-benchmarking_MPI_large_1_1.10.6_DP5.sh"

echo "Julia version:"
julia +1.10.6 --version

COMMAND=($MPIEXEC -n $SLURM_NTASKS 
         julia +1.11.1 --project="$PROJECT" 
         --optimize=3 
         --threads $SLURM_CPUS_PER_TASK 
	 $SCRIPT) 
echo ${COMMAND[@]} 
${COMMAND[@]} 



wait
exit

=#
using MPI
using PencilArrays
MPI.Init()

rank = 0
nranks = 1

if MPI.Initialized()
    rank = MPI.Comm_rank(MPI.COMM_WORLD)
    nranks = MPI.Comm_size(MPI.COMM_WORLD)
end

macro mpi_synchronize(expr)
    quote
    for r in 0:(nranks-1)
        if rank == r
            print("[$rank/$nranks]: ")
            $(esc(expr))
        end
        if MPI.Initialized()
            MPI.Barrier(MPI.COMM_WORLD)
        end
    end
    end
end

function print_barrier(args...)
    @mpi_synchronize println(args...)
end

workdir = "$nranks-dir$rank-$(Threads.nthreads())"
print_barrier("Removing data from previous runs ($workdir)")
rm(workdir, recursive=true, force=true) 
mkdir(workdir)
cd(workdir)

using ThreadPinning
pinthreads(:cores)


print_barrier("Loading SpinFRGLattices")
using SpinFRGLattices
print_barrier("Loading PMFRG")
using PMFRG
print_barrier("Loading PMFRGCore")
using PMFRGCore
print_barrier("Loading PMFRGSolve")
using PMFRGSolve
using SpinFRGLattices.SquareLattice
print_barrier("Loading TimerOutputs")
using TimerOutputs
print_barrier("Loading OrdinaryDiffEq")
using OrdinaryDiffEq

# This does not seem to work.
# TimerOutputs.enable_debug_timings(PMFRG)
# TimerOutputs.enable_debug_timings(Base.get_extension(PMFRG,:PMFRGMPIExt))
# Message is "timeit_debug_enable"
# This might instead do
Core.eval(PMFRG, :(timeit_debug_enabled()=true))
Core.eval(PMFRGCore, :(timeit_debug_enabled()=true))
Core.eval(Base.get_extension(PMFRGCore, :PMFRGCoreMPIExt), :(timeit_debug_enabled()=true))
Core.eval(PMFRGSolve, :(timeit_debug_enabled()=true))
Core.eval(Base.get_extension(PMFRGSolve, :PMFRGSolveMPIExt), :(timeit_debug_enabled()=true))

# Number of nearest neighbor bonds
# up to which correlations are treated in the lattice. 
# For NLen = 5, all correlations C_{ij} are zero 
#if sites i and j are separated by more than 5 nearest neighbor bonds.
NLenToy = 5 
NLen = 14 
J1 = 1
J2 = 0.1
# Construct a vector of couplings: 
# nearest neighbor coupling is J1 (J2) 
# and further couplings to zero.
# For finite further couplings simply provide a longer array, 
# i.e [J1,J2,J3,...]
couplings = [J1, J2] 

# create a structure that contains all information about the geometry of the problem.

print_barrier("GetSquareLattice - system toy")
SystemToy = getSquareLattice(NLenToy, couplings)

print_barrier("Warm up")

print_barrier("Get Params - toy")
Par = Params( #create a group of all parameters to pass them to the FRG Solver
    SystemToy, # geometry, this is always required
    OneLoop(), # method. OneLoop() is the default
    T=0.5, # Temperature for the simulation.
    N=10, # Number of positive Matsubara frequencies for the four-point vertex.
    accuracy=1e-3, #absolute and relative tolerance of the ODE solver.
    # For further optional arguments, see documentation of 'NumericalParams'
    MinimalOutput=true,
)

tempdir = "temp-$rank"
print_barrier("Removing data from previous runs ($tempdir)")
rm(tempdir, recursive=true, force=true)
mainFile = "$tempdir/" * PMFRG.generateFileName(Par, "_testFile") # specify a file name for main Output
flowpath = "$tempdir/flows/" # specify path for vertex checkpoints

print_barrier("SolveFRG - toy")
Solution, saved_values = SolveFRG(
    Par,
    UseMPI(),
    MainFile=mainFile,
    CheckpointDirectory=flowpath,
    method=DP5(thread=OrdinaryDiffEq.True()),
    VertexCheckpoints=[],
    CheckPointSteps=3,
);



print_barrier("Warmup done, timing real problem now.")

print_barrier("GetSquareLattice")
System = getSquareLattice(18, [1.]) 


print_barrier("Get Params")
Par = Params( #create a group of all parameters to pass them to the FRG Solver
    System, # geometry, this is always required
    OneLoop(), # method. OneLoop() is the default
    T=0.4, # Temperature for the simulation.
    N=50, # Number of positive Matsubara frequencies for the four-point vertex.
    accuracy=1e-9, #absolute and relative tolerance of the ODE solver.
    # For further optional arguments, see documentation of 'NumericalParams'
    MinimalOutput=true,
)

tempdir = "temp-$rank"
print_barrier("Removing data from previous runs ($tempdir)")
rm(tempdir, recursive=true, force=true)
mainFile = "$tempdir/" * PMFRG.generateFileName(Par, "_testFile") # specify a file name for main Output
flowpath = "$tempdir/flows/" # specify path for vertex checkpoints

reset_timer!()
print_barrier("SolveFRG")
@time Solution, saved_values = SolveFRG(
    Par,
    UseMPI(),
    MainFile=mainFile,
    CheckpointDirectory=flowpath,
    method=DP5(thread=OrdinaryDiffEq.True()),
    VertexCheckpoints=[],
    CheckPointSteps=3,
);

@mpi_synchronize print_timer()

if MPI.Initialized()
 MPI.Finalize()
end



