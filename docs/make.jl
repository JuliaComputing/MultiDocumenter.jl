using MultiDocumenter

clonedir = mktempdir()

docs = [
    MultiDocumenter.DropdownNav(
        "Debugging",
        [
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
        ],
    ),
    MultiDocumenter.MegaDropdownNav(
        "Mega Debugger",
        [
            MultiDocumenter.Column(
                "Column 1",
                [
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
                ],
            ),
            MultiDocumenter.Column(
                "Column 2",
                [
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
                ],
            ),
        ],
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "DataSets"),
        path = "data",
        name = "DataSets",
        giturl = "https://github.com/JuliaComputing/DataSets.jl.git",
        # or use ssh instead for private repos:
        # giturl = "git@github.com:JuliaComputing/DataSets.jl.git",
    ),
]

outpath = mktempdir()

MultiDocumenter.make(
    outpath,
    docs;
    search_engine = MultiDocumenter.SearchConfig(
        index_versions = ["stable"],
        engine = MultiDocumenter.FlexSearch,
    ),
)

gitroot = normpath(joinpath(@__DIR__, ".."))
run(`git pull`)
outbranch = "gh-pages"
has_outbranch = true
if !success(`git checkout $outbranch`)
    has_outbranch = false
    if !success(`git switch --orphan $outbranch`)
        @error "Cannot create new orphaned branch $outbranch."
        exit(1)
    end
end
for file in readdir(gitroot; join = true)
    endswith(file, ".git") && continue
    rm(file; force = true, recursive = true)
end
for file in readdir(outpath)
    cp(joinpath(outpath, file), joinpath(gitroot, file))
end
run(`git add .`)
if success(`git commit -m 'Aggregate documentation'`)
    @info "Pushing updated documentation."
    if has_outbranch
        run(`git push`)
    else
        run(`git push -u origin $outbranch`)
    end
    run(`git checkout main`)
else
    @info "No changes to aggregated documentation."
end
