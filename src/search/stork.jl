module Stork
import Pkg.TOML
import Gumbo, AbstractTrees
using HypertextLiteral
import ..walk_outputs

function has_stork()
    has_stork = false
    try
        has_stork = success(`stork -V`)
    catch
        has_stork = false
    end
    return has_stork
end

function build_search_index(root, docs, config, _)
    config = make_stork_config(root, docs, config)
    config_path = joinpath(root, "stork.config.toml")
    index_path = joinpath(root, "stork.st")
    open(config_path, "w") do io
        TOML.print(io, config)
    end
    run(`stork build --input $config_path --output $index_path`)
    return index_path
end

function make_stork_config(root, docs, config)
    files = []
    stork_config = Dict(
        "input" => Dict(
            "base_directory" => root,
            "html_selector" => "article",
            "files" => files,
        ),
        "output" => Dict("save_nearest_html_id" => true),
    )

    walk_outputs(root, docs, config.index_versions) do path, file
        add_to_index!(files, path, file)
    end

    return stork_config
end

function add_to_index!(files, ref, path)
    content = read(path, String)
    html = Gumbo.parsehtml(content)

    title = ""
    for el in AbstractTrees.PreOrderDFS(html.root)
        if el isa Gumbo.HTMLElement
            if Gumbo.tag(el) == :title
                title = first(split(Gumbo.text(el), " · "))
                break
            end
        end
    end

    push!(files, Dict("path" => path, "url" => ref, "title" => title))
    return
end

function inject_script!(custom_scripts, _)
    pushfirst!(custom_scripts, joinpath("assets", "default", "stork.js"))
    pushfirst!(custom_scripts, joinpath("assets", "default", "stork_integration.js"))
end

function inject_styles!(custom_styles)
    pushfirst!(custom_styles, joinpath("assets", "default", "stork.css"))
end

function render()
    return @htl """
    <div class="search nav-item stork-wrapper">
        <input id="search-input" class="stork-input" data-stork="multidocumenter" placeholder="Search...">
        <div data-stork="multidocumenter-output" class="stork-output"></div>
        <div class="search-keybinding">/</div>
    </div>
    """
end
end
