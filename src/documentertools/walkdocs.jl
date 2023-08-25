# This is vendored version of code that should eventually moved into DocumenterTools.jl
# once the generic interface has crystallized, and then DocumenterTools should be added
# as a dependency here.
#
# WIP upstream PR: https://github.com/JuliaDocs/DocumenterTools.jl/pull/75
#
# Note: these functions are not part of MultiDocumenter public API.

"""
    struct FileInfo

Objects of this type are passed as arguments to the callback of the [`walkdocs`](@ref) function.
See [`walkdocs`](@ref) for information on how to interpret the docstrings.
"""
Base.@kwdef struct FileInfo
    root::String
    filename::String
    relpath::String
    fullpath::String
end

"""
    isdochtml(::Fileinfo) -> Bool

Checks if the file is a Documenter-generated HTML file.
"""
function isdochtml(fileinfo::FileInfo)
    _, ext = splitext(fileinfo.filename)
    # While currently the function only checks for the file extension, the semantics of
    # this predicate are such that it might also look at the contents of the file and do
    # other heuristics. I.e. we can make this function smarted as needed.
    return ext == ".html"
end

"""
    walkdocs(f, dir::AbstractString[, filter_cb]; collect::Bool=false)

Takes a directory `dir`, which is assumed to contain Documenter-generated documentation,
walks over all the files and calls `f` on each of the files it find. Optionally, a
`filter_cb(::FileInfo)` function can be passed to only call `f` on files for which it returns
`true`.

`f` and `filter_cb` will be called with a single object that has the following fields (all strings):

- `.root`: the root directory of the walk, i.e. `dir` (but as an absolute path)
- `.filename`: file name
- `.relpath`: path to the file, relative to `dir`
- `.fullpath`: absolute path to the file

See also the [`FileInfo`](@ref) struct.

If `collect = true` is set, the function also "collects" all the return values from `f`
from each of the function calls, essentially making `walkdocs` behave like a `map` function
applied on each of the HTML files.

```julia
walkdocs(directory_root, filter = isdochtml) do fileinfo
    @show fileinfo.fullpath
end
```
"""
function walkdocs(f, dir::AbstractString, filter_cb = _ -> true; collect::Bool = false)
    hasmethod(f, (FileInfo,)) || throw(MethodError(f, (FileInfo,)))
    hasmethod(filter_cb, (FileInfo,)) || throw(MethodError(filter_cb, (FileInfo,)))

    dir = abspath(dir)
    isdir(dir) || error("docwalker: dir is not a directory\n dir = $(dir)")

    mapped_collection = collect ? Any[] : nothing
    for (root, _, files) in walkdir(dir)
        for file in files
            file_fullpath = joinpath(root, file)
            file_relpath = Base.relpath(file_fullpath, dir)
            fileinfo = FileInfo(;
                root = dir,
                filename = file,
                relpath = file_relpath,
                fullpath = file_fullpath,
            )
            # Check that the file actually matches the filter, and only then
            # call the callback f().
            if filter_cb(fileinfo)
                r = f(fileinfo)
                if collect
                    push!(mapped_collection, r)
                end
            end
        end
    end
    return mapped_collection
end
