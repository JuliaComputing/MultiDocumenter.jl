# MultiDocumenter

This package aggregates [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) documentation from multiple sources into one page with a global search bar.

## Example usage
```julia
using MultiDocumenter

clonedir = mktempdir()

docs = [
    MultiDocumenter.DropdownNav("Debugging", [
        MultiDocumenter.MultiDocRef(
            upstream = joinpath(clonedir, "Infiltrator"),
            path = "inf",
            name = "Infiltrator",
            giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
        ),
        MultiDocumenter.MultiDocRef(
            upstream = joinpath(clonedir, "JuliaInterpreter"),
            path = "debug",
            name = "JuliaInterpreter",
            giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
        ),
    ]),
    MultiDocumenter.MegaDropdownNav("Mega Debugger", [
        MultiDocumenter.Column("Column 1", [
            MultiDocumenter.MultiDocRef(
                upstream = joinpath(clonedir, "Infiltrator"),
                path = "inf",
                name = "Infiltrator",
                giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
            ),
            MultiDocumenter.MultiDocRef(
                upstream = joinpath(clonedir, "JuliaInterpreter"),
                path = "debug",
                name = "JuliaInterpreter",
                giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
            ),
        ]),
        MultiDocumenter.Column("Column 2", [
            MultiDocumenter.MultiDocRef(
                upstream = joinpath(clonedir, "Infiltrator"),
                path = "inf",
                name = "Infiltrator",
                giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
            ),
            MultiDocumenter.MultiDocRef(
                upstream = joinpath(clonedir, "JuliaInterpreter"),
                path = "debug",
                name = "JuliaInterpreter",
                giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
            ),
        ]),
    ]),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "DataSets"),
        path = "data",
        name = "DataSets",
        giturl = "https://github.com/JuliaComputing/DataSets.jl.git",
        # or use ssh instead for private repos:
        # giturl = "git@github.com:JuliaComputing/DataSets.jl.git",
    ),
]

outpath = joinpath(@__DIR__, "out")

MultiDocumenter.make(
    outpath,
    docs;
    search_engine = MultiDocumenter.SearchConfig(
        index_versions = ["stable"],
        engine = MultiDocumenter.FlexSearch
    )
)
```

![example](sample.png)

## Deployment

Check [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) and [`docs/make.jl`](docs/make.jl) for an example on how to deploy MultiDocumenter-generated aggregates to a git branch.

The result of that script is available at [https://juliacomputing.github.io/MultiDocumenter.jl/](https://juliacomputing.github.io/MultiDocumenter.jl/).

You can of course also just push the output artefact directly to S3 or some other hosting service.

> **Warning**
> MultiDocumenter sites can not be deployed on Windows right now.
> See [#70](https://github.com/JuliaComputing/MultiDocumenter.jl/issues/70).
