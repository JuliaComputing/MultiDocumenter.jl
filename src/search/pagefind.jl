module PageFind
using NodeJS_22_jll: npx, npm
using HypertextLiteral: @htl

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
    if !success(Cmd(`$(npx) pagefind -V`; dir = root))
        @info "Installing pagefind into $root."
        if !success(Cmd(`$(npm) install pagefind`; dir = root))
            error("Could not install pagefind.")
        end
    end

    pattern = "*/{$(join(config.index_versions, ","))}/**/*.{html}"

    out_path = joinpath(root, "pagefind")
    mktempdir() do dir
        # pagefind doesn't look at symlinks, so we resolve them here:
        cp(root, dir; follow_symlinks = true, force = true)
        run(`$(npx) pagefind --site $(dir) --output-path $(out_path) --glob $(pattern) --root-selector article`)
    end

    return nothing
end

end
