using MPI
using PencilArrays

using ThreadPinning
pinthreads(:cores)


using SpinFRGLattices
using PMFRG
using PMFRGCore
using PMFRGSolve
using SpinFRGLattices.SquareLattice
using TimerOutputs
using OrdinaryDiffEq





function get_integration_method(ARGS)
    SOLVERMETHOD = ARGS[1]
    if SOLVERMETHOD == "DP5"
        DP5(thread=OrdinaryDiffEq.True())
    elseif SOLVERMETHOD == "VCABM"
        VCABM(true)
    end
end


function warmup(integration_method)
    # Number of nearest neighbor bonds
    # up to which correlations are treated in the lattice.
    # For NLen = 5, all correlations C_{ij} are zero
    #if sites i and j are separated by more than 5 nearest neighbor bonds.
    NLenToy = 5
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

    _ = SolveFRG(
        Par,
        UseMPI(),
        MainFile=mainFile,
        CheckpointDirectory=flowpath,
        method=integration_method,
        VertexCheckpoints=[],
        CheckPointSteps=3,
    )

end


function medium_problem(integration_method)
    print_barrier("GetSquareLattice")

    NLen = 14
    J1 = 1
    J2 = 0.1
    couplings = [J1, J2]

    System = getSquareLattice(NLen, couplings)


    print_barrier("Get Params")
    Par = Params( #create a group of all parameters to pass them to the FRG Solver
        System, # geometry, this is always required
        OneLoop(), # method. OneLoop() is the default
        T=0.5, # Temperature for the simulation.
        N=25, # Number of positive Matsubara frequencies for the four-point vertex.
        accuracy=1e-3, #absolute and relative tolerance of the ODE solver.
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
        method=integration_method,
        VertexCheckpoints=[],
        CheckPointSteps=3,
    )


    @mpi_synchronize print_timer()

end

function large_problem(integration_method)
    print_barrier("GetSquareLattice")
    System = getSquareLattice(18, [1.0])


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
        method=integration_method,
        VertexCheckpoints=[],
        CheckPointSteps=3,
    )

    @mpi_synchronize print_timer()


end

MPI.Init()

rank = MPI.Comm_rank(MPI.COMM_WORLD)
nranks = MPI.Comm_size(MPI.COMM_WORLD)

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


function create_and_cd_into_workdir(ARGS)
    suffix=join(ARGS,"_")
    workdir = "dir-$rank/$nranks-$(Threads.nthreads())-$suffix"
    print_barrier("Removing data from previous runs ($workdir)")
    rm(workdir, recursive=true, force=true)
    mkdir(workdir)
    cd(workdir)
end



function activate_timers()
    # This does not seem to work.
    # TimerOutputs.enable_debug_timings(PMFRG)
    # TimerOutputs.enable_debug_timings(Base.get_extension(PMFRG,:PMFRGMPIExt))
    # Message is "timeit_debug_enable"
    # This might instead do
    Core.eval(PMFRG, :(timeit_debug_enabled() = true))
    Core.eval(PMFRGCore, :(timeit_debug_enabled() = true))
    Core.eval(Base.get_extension(PMFRGCore, :PMFRGCoreMPIExt), :(timeit_debug_enabled() = true))
    Core.eval(PMFRGSolve, :(timeit_debug_enabled() = true))
    Core.eval(Base.get_extension(PMFRGSolve, :PMFRGSolveMPIExt), :(timeit_debug_enabled() = true))

end



create_and_cd_into_workdir(ARGS)
activate_timers()
integration_method = get_integration_method(ARGS)
warmup(integration_method)

if ARGS[2] == "medium"
    medium_problem(integration_method)
elseif ARGS[2] == "large"
    large_problem(integration_method)
end

MPI.Finalize()
