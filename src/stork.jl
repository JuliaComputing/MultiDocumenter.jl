module Stork
# there's no UI for this yet
import Pkg.TOML
import Gumbo

function build_search_index(root)
    config = make_stork_config(root)
    config_path = joinpath(root, "stork.config.toml")
    index_path = joinpath(root, "stork.st")
    open(config_path, "w") do io
        TOML.print(io, config)
    end
    run(`stork build --input $config_path --output $index_path`)
    return index_path
end

function make_stork_config(root)
    files = []
    config = Dict(
        "input" => Dict(
            "base_directory" => root,
            "html_selector" => "article",
            "files" => files
        ),
    )
    for (r, _, fs) in walkdir(root)
        for file in fs
            if file == "index.html"
                print(".")
                add_to_index!(files, chop(r, head = length(root), tail = 0), joinpath(r, file))
            end
        end
    end

    return config
end

function add_to_index!(files, ref, path)
    content = read(path, String)
    html = Gumbo.parsehtml(content)

    title = ""
    for el in AbstractTrees.PreOrderDFS(html.root)
        if el isa Gumbo.HTMLElement
            if Gumbo.tag(el) == :title
                title = Gumbo.text(el)
                break
            end
        end
    end

    push!(files, Dict(
        "path" => path,
        "url" => ref,
        "title" => title
    ))
    return
end
end