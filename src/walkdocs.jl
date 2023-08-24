# This is borrowed from DocumenterTools.walkdocs (MIT)

"""
    walkdocs(f, dir::AbstractString; collect::Bool=false)

Takes a directory `dir`, which is assumed to contain Documenter-generated HTML documentation,
walks over all the files and calls `f` on each of the HTML files it find. `f` will be called
with a single object that has the following fields (all strings):

- `root`: the root directory of the walk, i.e. `dir` (but as an absolute path)
- `filename`: file name
- `relpath`: path to the file, relative to `dir`
- `fullpath`: absolute path to the file

If `collect = true` is set, the function also "collects" all the return values from `f`
from each of the function calls, essentially making `walkdocs` behave like a `map` function
applied on each of the HTML files.
"""
function walkdocs(f, dir::AbstractString; collect::Bool=false)
    dir = abspath(dir)
    isdir(dir) || error("docwalker: dir is not a directory\n dir = $(dir)")

    mapped_collection = collect ? Any[] : nothing
    for (root, _, files) in walkdir(dir)
        for file in files
            _, ext = splitext(file)
            (ext == ".html") || continue
            file_fullpath = joinpath(root, file)
            file_relpath = Base.relpath(file_fullpath, dir)
            fileinfo = (;
                root = dir,
                filename = file,
                relpath = file_relpath,
                fullpath = file_fullpath,
            )
            r = f(fileinfo)
            if collect
                push!(mapped_collection, r)
            end
        end
    end
    return mapped_collection
end
