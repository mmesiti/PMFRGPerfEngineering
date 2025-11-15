
using MPI
using PencilArrays
using Pkg

import ThreadPinning: pinthreads, threadinfo
using SpinFRGLattices
using PMFRG
if "PMFRGCore" in [v.name for v in values(Pkg.dependencies())]
    # from:
    # https://discourse.julialang.org/t/new-pkg-how-to-check-if-a-package-is-installed/13141/5
    @eval using PMFRGCore
    @eval using PMFRGSolve
end

using SpinFRGLattices.SquareLattice
using TimerOutputs
using OrdinaryDiffEq
using Static

#

macro mpi_synchronize(expr)
    quote
        let 
            rank = MPI.Comm_rank(MPI.COMM_WORLD)
            nranks = MPI.Comm_size(MPI.COMM_WORLD)
     
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
end

macro mpi_master_only(expr)
    quote
        let 
            rank = MPI.Comm_rank(MPI.COMM_WORLD)
            nranks = MPI.Comm_size(MPI.COMM_WORLD)
     
            if rank == 0
                print("[$rank/$nranks]: ")
                $(esc(expr))
            end
            if MPI.Initialized()
                MPI.Barrier(MPI.COMM_WORLD)
            end
        end
    end

end

#

function main()
    println("Initializing MPI...")
    MPI.Init()
    print_barrier("Initialized MPI...")

    @mpi_master_only print_version()

    rank = MPI.Comm_rank(MPI.COMM_WORLD)
    nranks = MPI.Comm_size(MPI.COMM_WORLD)
    print_barrier("Pinning threads...")
    pinthreads(:cores)
    @mpi_synchronize threadinfo(; color=false, slurm=true)

    create_and_cd_into_workdir(rank,nranks,ARGS)
    #activate_timers() # There is no reliable way to activate debug timers
    integration_method = get_integration_method(ARGS)
    warmup(integration_method)
    reset_timer!()

    if ARGS[2] == "medium"
        medium_problem(integration_method)
    elseif ARGS[2] == "large"
        large_problem(integration_method)
    end

    MPI.Finalize()

end

##

function print_version()
   Pkg.status(mode=PKGMODE_MANIFEST)
end

function save_env(filename)
    open(filename,"w") do f
        for (k,v) in ENV
            write(f,"$k=$v\n")
        end
    end
end

function create_and_cd_into_workdir(rank,nranks,ARGS)
    suffix = join(ARGS, "_")
    git_commit = get_PMFRG_git_commit()
    slurm_jobid_suffix=get(ENV,"SLURM_JOB_ID","xxxxxxx")
    workdir = "dir-$rank-of-$nranks-$(Threads.nthreads())-$suffix-$(git_commit[1:7])-$slurm_jobid_suffix"
    print_barrier("Removing data from previous runs ($workdir)")
    rm(workdir, recursive=true, force=true)
    mkdir(workdir)
    cd(workdir)
end

function activate_timers()
    # There seems to be no reliable way to activate debug timers.
    # They might work for PMFRGCore, 
    # But not for PMFRGSolve,
    # For weird reasons.
    # This does not seem to work, but let's try it anyway
    TimerOutputs.enable_debug_timings(PMFRG)
    TimerOutputs.enable_debug_timings(Base.get_extension(PMFRG,:PMFRGMPIExt))
    # Message is "timeit_debug_enable"
    # This might instead do
    Core.eval(PMFRG, :(timeit_debug_enabled() = true))
    if "PMFRGCore" in [v.name for v in values(Pkg.dependencies())]
        # from:
        # https://discourse.julialang.org/t/new-pkg-how-to-check-if-a-package-is-installed/13141/5

        TimerOutputs.enable_debug_timings(PMFRGCore)
        TimerOutputs.enable_debug_timings(Base.get_extension(PMFRGCore,:PMFRGCoreMPIExt))

        TimerOutputs.enable_debug_timings(PMFRGSolve)
        TimerOutputs.enable_debug_timings(Base.get_extension(PMFRGSolve,:PMFRGSolveMPIExt))

        Core.eval(PMFRGCore, :(timeit_debug_enabled() = true))
        Core.eval(Base.get_extension(PMFRGCore, :PMFRGCoreMPIExt), :(timeit_debug_enabled() = true))
        Core.eval(PMFRGSolve, :(timeit_debug_enabled() = true))
        Core.eval(Base.get_extension(PMFRGSolve, :PMFRGSolveMPIExt), :(timeit_debug_enabled() = true))

    end
end



function get_integration_method(ARGS)
    SOLVERMETHOD = ARGS[1]
    if SOLVERMETHOD == "DP5"
        DP5(thread=Static.True())
    elseif SOLVERMETHOD == "VCABM"
        VCABM(thread=Static.True())
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

    tempdir = "temp"
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

    tempdir = "temp"
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

    tempdir = "temp"
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

###

function get_PMFRG_git_commit()
    print_barrier("finding git commit...")
    pmfrg_path = first( v.source for (_,v) in Pkg.dependencies() if v.name == "PMFRG")
    out = Pipe()
    run(pipeline(`git -C $pmfrg_path rev-parse HEAD`, stdout=out))
    close(out.in)
    String(read(out))
end

function print_barrier(args...)
    @mpi_synchronize println(args...)
end


####


main()
