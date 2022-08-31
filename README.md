# MultiDocumenter

This package aggregates [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) documentation from multiple sources into one page with a global search bar.

## Example usage
```julia
using MultiDocumenter

clonedir = mktempdir()

docs = [
    ("JuliaDocs/Documenter.jl.git", "gh-pages") => MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "Documenter"),
        path = "doc",
        name = "Documenter"
    ),
    ("JuliaDebug/Infiltrator.jl.git", "gh-pages") => MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "Infiltrator"),
        path = "inf",
        name = "Infiltrator"
    ),
]

for ((remote, branch), docref) in docs
    run(`git clone --depth 1 git@github.com:$remote --branch $branch --single-branch $(docref.upstream)`)
end

outpath = joinpath(@__DIR__, "out")

MultiDocumenter.make(
    outpath,
    collect(last.(docs));
    search_engine = MultiDocumenter.SearchConfig(
        index_versions = ["stable"],
        engine = MultiDocumenter.FlexSearch
    )
)
```

![example](sample.png)
