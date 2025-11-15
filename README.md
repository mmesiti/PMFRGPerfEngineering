# Performance Engineering Script Collection for PMFRG

Loose collection of scripts, tools and notes
used in the performance characterization 
of Nils Niggeman's [PMFRG.jl code](https://github.com/NilsNiggemann/PMFRG.jl).


## Custom Registry

To manage the dependencies it can be useful to install

https://github.com/NilsNiggemann/JuliaPMFRGRegistry


## What is what

Brief description of which script does what

### General
All scripts mentioned here should be julia-version agnostic.
Quite some care must be made to make sure that they run in their own environment
and the environment must match the julia version, 
or there can be problems.
Also, MPIPreferences.use_system_binary() 
must have been run in the environment, 
otherwise terrible performance might ensue. 

## How to use: for performance tweaking
This package is intended to be a client 
of some the other packages
in the PMFRG ecosystem.

These packages need to be added as dev dependencies
to this one
all at once,
using 
```julia
] dev https://github.com/NilsNiggemann/SpinFRGLattices.jl.git ./PMFRG.jl ./PMFRG.jl/PMFRGCore.jl ./PMFRG.jl/PMFRGSolve.jl
```
in this way the packages can be benchmarked 
and changed freely.


## Using the driver
Examples:
```bash
PMFRGPATH=../PMFRG.jl PROJECT=./config-post-master/ bash src/driver.sh main 76 1
PMFRGPATH=../PMFRG.jl PROJECT=./config-post-master/ bash src/driver.sh main 38 2
PMFRGPATH=../PMFRG.jl-master PROJECT=./config-master/ bash src/driver.sh main 76 1
PMFRGPATH=../PMFRG.jl-master PROJECT=./config-master/ bash src/driver.sh main 38 2
```
