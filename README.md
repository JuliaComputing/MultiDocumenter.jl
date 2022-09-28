# MultiDocumenter

This package aggregates [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) documentation from multiple sources into one page with a global search bar.

## Example usage
```julia
using MultiDocumenter

clonedir = mktempdir()

docs = [
    ("JuliaDocs/Documenter.jl.git", "gh-pages", false) => MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "Documenter"),
        path = "doc",
        name = "Documenter"
    ),
    # using SSH for cloning is suggested when you're dealing with private repos, because
    # an ssh-agent will handle your keys for you
    # ("JuliaDebug/Infiltrator.jl.git", "gh-pages", true) => MultiDocumenter.MultiDocRef(
    ("JuliaDebug/Infiltrator.jl.git", "gh-pages", false) => MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "Infiltrator"),
        path = "inf",
        name = "Infiltrator"
    ),
]

for ((remote, branch, prefix), docref) in docs
    prefix = use_ssh ? "git@github.com:" : "https://github.com/"
    run(`git clone --depth 1 $prefix$remote --branch $branch --single-branch $(docref.upstream)`)
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
