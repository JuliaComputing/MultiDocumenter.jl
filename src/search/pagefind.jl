module PageFind
using NodeJS_22_jll: npx, npm, node
using HypertextLiteral: @htl
import ..warn_unindexed_refs

"""
    npm_command(shim, args...; dir) -> Cmd

Command that runs one of NodeJS jll's `npm` / `npx` file products with `args`, in `dir`.
"""
function npm_command(
        shim::AbstractString,
        args::AbstractString...;
        dir::AbstractString
    )
    Sys.iswindows() || return Cmd(`$(shim) $(String[args...])`; dir = dir)

    wincmd_arg(arg::AbstractString) =
        Base.shell_escape_wincmd(occursin(' ', arg) ? "\"$(arg)\"" : arg)

    line = join((wincmd_arg(arg) for arg in (shim * ".cmd", args...)), ' ')
    return Cmd(Cmd(["cmd.exe", "/S /C \"$(line)\""]); windows_verbatim = true, dir = dir)
end

function inject_script!(custom_scripts, rootpath)
    pushfirst!(custom_scripts, joinpath("assets", "default", "pagefind_integration.js"))
    pushfirst!(custom_scripts, joinpath("pagefind", "pagefind.js"))
    pushfirst!(
        custom_scripts,
        Docs.HTML("window.MULTIDOCUMENTER_ROOT_PATH = '$(rootpath)'"),
    )
    return nothing
end

function inject_styles!(custom_styles)
    pushfirst!(custom_styles, joinpath("assets", "default", "pagefind.css"))
    return nothing
end

function render()
    return @htl """
    <div class="search nav-item">
        <input id="search-input" placeholder="Search everywhere...">
        <ol id="search-result-container" class="suggestions hidden">
        </ol>
        <div class="search-keybinding">/</div>
    </div>
    """
end

function build_search_index(root, docs, config, rootpath)
    # npx and npm are distributed as FileProducts,
    # so the JLL does not bundle environment information into them.
    # To fix this, we wrap all uses of npx and npm inside `node() do ...`
    # which will automatically adjust the necessary environment variables.
    node() do _
        if !success(npm_command(npx, "pagefind", "-V"; dir = root))
            @info "Installing pagefind into $root."
            if !success(npm_command(npm, "install", "pagefind"; dir = root))
                error("Could not install pagefind.")
            end
        end

        warn_unindexed_refs(root, docs, config.index_versions)

        pattern = "*/{$(join(config.index_versions, ","))}/**/*.{html}"

        out_path = joinpath(root, "pagefind")
        mktempdir() do sitedir
            # pagefind doesn't look at symlinks, so we resolve them here:
            cp(root, sitedir; follow_symlinks = true, force = true)
            run(
                npm_command(
                    npx, "pagefind",
                    "--site", sitedir,
                    "--output-path", out_path,
                    "--glob", pattern,
                    "--root-selector", "article";
                    dir = root,
                )
            )
        end
    end

    return nothing
end

end
