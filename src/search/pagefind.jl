module PageFind
using NodeJS: NodeJS
using HypertextLiteral

function inject_script!(custom_scripts, rootpath)
    pushfirst!(custom_scripts, joinpath("assets", "default", "pagefind_integration.js"))
    pushfirst!(custom_scripts, joinpath("pagefind", "pagefind.js"))
end

function inject_styles!(custom_styles)
    pushfirst!(custom_styles, joinpath("assets", "default", "pagefind.css"))
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
    if !success(`npx pagefind -V`)
        error("pagefind search engine not found. Aborting. Try running `npm install pagefind --global`")
    end

    pattern = "*/{$(join(config.index_versions, ","))}/**/*.{html}"

    run(`npx pagefind --site $(root) --glob $(pattern) --root-selector article --exclude-selectors pre`)
end

end