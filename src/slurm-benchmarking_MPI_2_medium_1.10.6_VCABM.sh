#!/bin/bash
#=
#SBATCH --partition cpuonly
#SBATCH --time 15
#SBATCH --nodes 2
#SBATCH --ntasks-per-node 1
#SBATCH --cpus-per-task=76
#SBATCH --exclusive
#SBATCH --dependency singleton
#SBATCH --job-name pmfrg-benchmark

PROJECT="$PWD"

set -o nounset
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
SCRIPT="$PROJECT/src/slurm-benchmarking_MPI_2_medium_1.10.6_VCABM.sh"

echo "Julia version:"
julia +1.10.6 --version

COMMAND=($MPIEXEC -n $SLURM_NTASKS
         julia +1.10.6 --project="$PROJECT" 
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
workdir = "medium2-dir-$(Threads.nthreads())"
println("Removing data from previous runs ($workdir)")
r2(workdir, recursive=true, force=true) 
mkdir(workdir)
cd(workdir)

using ThreadPinning
pinthreads(:cores)

println("Loading SpinFRGLattices")
using SpinFRGLattices
println("Loading PMFRG")
using PMFRG
println("Loading PMFRGCore")
using PMFRGCore
println("Loading PMFRGSolve")
using PMFRGSolve
using SpinFRGLattices.SquareLattice
println("Loading TimerOutputs")
using TimerOutputs
println("Loading OrdinaryDiffEq")
using OrdinaryDiffEq

# This does not seem to work.
# TimerOutputs.enable_debug_timings(PMFRG)
# TimerOutputs.enable_debug_timings(Base.get_extension(PMFRG,:PMFRGMPIExt))
# Message is "timeit_debug_enable"
# This might instead do
Core.eval(PMFRG, :(timeit_debug_enabled()=true))
Core.eval(PMFRGCore, :(timeit_debug_enabled()=true))
Core.eval(PMFRGSolve, :(timeit_debug_enabled()=true))

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

println("GetSquareLattice - system toy")
SystemToy = getSquareLattice(NLenToy, couplings)

println("GetSquareLattice")
System = getSquareLattice(NLen, couplings) 

println("Warm up")

println("Get Params - toy")
Par = Params( #create a group of all parameters to pass them to the FRG Solver
    SystemToy, # geometry, this is always required
    OneLoop(), # method. OneLoop() is the default
    T=0.5, # Temperature for the simulation.
    N=10, # Number of positive Matsubara frequencies for the four-point vertex.
    accuracy=1e-3, #absolute and relative tolerance of the ODE solver.
    # For further optional arguments, see documentation of 'NumericalParams'
    MinimalOutput=true,
)

tempdir = "temp-0"
println("Removing data from previous runs ($tempdir)")
rm(tempdir, recursive=true, force=true)
mainFile = "$tempdir/" * PMFRG.generateFileName(Par, "_testFile") # specify a file name for main Output
flowpath = "$tempdir/flows/" # specify path for vertex checkpoints

println("SolveFRG - toy")
_ = SolveFRG(
    Par,
    UseMPI(),
    MainFile=mainFile,
    CheckpointDirectory=flowpath,
    method=VCABM(true),
    VertexCheckpoints=[],
    CheckPointSteps=3,
);



println("Warmup done, timing real problem now.")


println("Get Params")
Par = Params( #create a group of all parameters to pass them to the FRG Solver
    System, # geometry, this is always required
    UseMPI(),
    T=0.5, # Temperature for the simulation.
    N=40, # Number of positive Matsubara frequencies for the four-point vertex.
    accuracy=1e-4, #absolute and relative tolerance of the ODE solver.
    # For further optional arguments, fsee documentation of 'NumericalParams'
    MinimalOutput=true,
)

tempdir = "temp-0"
println("Removing data from previous runs ($tempdir)")
rm(tempdir, recursive=true, force=true)
mainFile = "$tempdir/" * PMFRG.generateFileName(Par, "_testFile") # specify a file name for main Output
flowpath = "$tempdir/flows/" # specify path for vertex checkpoints


reset_timer!()
println("SolveFRG")
_ = SolveFRG(
    Par,
    MultiThreaded(),
    MainFile=mainFile,
    CheckpointDirectory=flowpath,
    method=VCABM(true),
    VertexCheckpoints=[],
    CheckPointSteps=3,
);

print_timer()


