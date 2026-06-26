module PageFind
using NodeJS_22_jll: npx, npm, node
using HypertextLiteral: @htl

# NodeJS_22_jll exposes `npx` / `npm` as either plain path strings (newer Julia / JLL)
# or zero-arg callables returning the path.
function _jll_executable_path(x)::String
    x isa AbstractString && return String(x)
    try
        return String(x())
    catch
        return String(x)
    end
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
        npx_exe = _jll_executable_path(npx)
        npm_exe = _jll_executable_path(npm)
        version_ok = cd(root) do
            success(Cmd([npx_exe, "pagefind", "-V"]))
        end
        if !version_ok
            @info "Installing pagefind into $root."
            installed = cd(root) do
                success(Cmd([npm_exe, "install", "pagefind"]))
            end
            installed || error("Could not install pagefind.")
        end

        pattern = "*/{$(join(config.index_versions, ","))}/**/*.{html}"

        out_path = joinpath(root, "pagefind")
        mktempdir() do dir
            # pagefind doesn't look at symlinks, so we resolve them here:
            cp(root, dir; follow_symlinks = true, force = true)
            run(
                Cmd(
                    [
                        npx_exe,
                        "pagefind",
                        "--site",
                        dir,
                        "--output-path",
                        out_path,
                        "--glob",
                        pattern,
                        "--root-selector",
                        "article",
                    ],
                ),
            )
        end
    end

    return nothing
end

end
