module MultiDocumenter

import Gumbo, AbstractTrees
using HypertextLiteral
import Git: git

module DocumenterTools
import Gumbo, AbstractTrees
include("documentertools/walkdocs.jl")
include("documentertools/canonical_urls.jl")
end

"""
    SearchConfig(index_versions = ["stable"], engine = MultiDocumenter.FlexSearch, lowfi = false)

`index_versions` is a vector of relative paths used for generating the search index. Only
the first matching path is considered.
`engine` may be `MultiDocumenter.FlexSearch`, `MultiDocumenter.Stork`, or a module that conforms
to the expected API (which is currently undocumented).
`lowfi = true` will try to minimize search index size. Only relevant for flexsearch.
"""
Base.@kwdef mutable struct SearchConfig
    index_versions = ["stable", "dev"]
    engine = FlexSearch
    lowfi = false
end

"""
    abstract type DropdownComponent

The supertype for any component that can be put in a dropdown column and 
rendered using `MultiDocumenter.render(::YourComponent, thispagepath, dir, prettyurls)`.  

All `DropdownComponent`s go in [`Column`](@ref)s, which go in [`MegaDropdownNav`](@ref).

Any subtype of `DropdownComponent` must implement that `render` method.

The main subtype is [`MultiDocRef`](@ref), which refers to external documentation
and adds it to the search index.  However, there are others like [`Link`](@ref)
which is used to link to external sites without making them searchable, and
users can implement their own custom components.
"""
abstract type DropdownComponent end

"""
    struct MultiDocRef <: DropdownComponent
    MultiDocRef(; upstream, name, path, giturl = "", branch = "gh-pages", fix_canonical_url = true)

Represents one set of docs that will get an entry in the MultiDocumenter navigation.

**Required arguments:**

* `upstream`: the local directory where the documentation is located. If `giturl` is passed,
  MultiDocumenter will clone into this directory.
* `name`: string used in the MultiDocumenter navigation for this item
* `path`: the URL path under which the contents of upstream is placed

**Optional arguments:**

* `giturl`: URL of the remote Git repository that will be cloned. If this is unset, then `upstream` must be an existing directory.
* `branch`: Git branch of `giturl` where the docs will be pulled from (defaults to `gh-pages`)
* `fix_canonical_url`: this can be set to `false` to disable the canonical URL fixing
  for this `MultiDocRef` (see also `canonical_domain` for [`make`](@ref)).
"""
struct MultiDocRef <: DropdownComponent
    upstream::String
    path::String
    name::Any
    fix_canonical_url::Bool
    giturl::String
    branch::String
end

function MultiDocRef(;
    upstream,
    name,
    path,
    giturl = "",
    branch = "gh-pages",
    fix_canonical_url = true,
)
    MultiDocRef(upstream, path, name, fix_canonical_url, giturl, branch)
end

"""
    Link([text::String], link::String) <: DropdownComponent

Represents a link to an external site.
"""
struct Link <: MultiDocumenter.DropdownComponent
    text::String
    link::String
end

Link(link::String) = Link(link, link)

struct DropdownNav
    name::String
    children::Vector{DropdownComponent}
end

struct Column
    name::Any
    children::Vector{DropdownComponent}
end

struct MegaDropdownNav
    name::Any
    columns::Vector{Column}
end

struct BrandImage
    path::String
    imagepath::String
end

function walk_outputs(f, root, docs::Vector, dirs::Vector{String})
    for ref in filter(x -> x isa MultiDocRef, docs)
        p = joinpath(root, ref.path)
        for dir in dirs
            dirpath = joinpath(p, dir)
            isdir(dirpath) || continue
            DocumenterTools.walkdocs(dirpath, DocumenterTools.isdochtml) do fileinfo
                f(relpath(dirname(fileinfo.fullpath), root), fileinfo.fullpath)
            end
            break
        end
    end
end

include("renderers.jl")
include("search/flexsearch.jl")
include("search/stork.jl")
include("canonical.jl")
include("sitemap.jl")

const DEFAULT_ENGINE = SearchConfig(index_versions = ["stable", "dev"], engine = FlexSearch)

"""
    make(
        outdir,
        docs::Vector{MultiDocRef};
        assets_dir,
        brand_image,
        custom_stylesheets = [],
        custom_scripts = [],
        search_engine = SearchConfig(),
        prettyurls = true,
        rootpath = "/",
        hide_previews = true,
        canonical = nothing,
    )

Aggregates multiple Documenter.jl-based documentation pages `docs` into `outdir`.

- `assets_dir` is copied into `outdir/assets`
- `brand_image` is a `BrandImage(path, imgpath)`, which is rendered as the leftmost
  item in the global navigation
- `custom_stylesheets` is a `Vector{String}` of relative stylesheet URLs injected into each page.
- `custom_scripts` is a `Vector{Union{String, Docs.HTML}}`. Strings can be relative or absolute URLs, while
  `Docs.HTML` objects are inserted as the content of inline scripts.
- `search_engine` inserts a global search bar if not `false`. See [`SearchConfig`](@ref) for more details.
- `prettyurls` removes all `index.html` suffixes from links in the global navigation.
- `rootpath` is the path your site ends up being deployed at, e.g. `/foo/` if it's hosted at `https://bar.com/foo`
- `hide_previews` removes preview builds from the aggregated documentation.
- `canonical_domain`: determines the the schema and authority (domain) of the (e.g. `https://example.org`)
  deployed site. If set, MultiDocumenter will check and, if necessary, update the canonical URL tags for each
  package site to point to the correct place directory. Similar to the `canonical` argument of `Documenter.HTML`
  constructor, except that it should not contain the path component -- that is determined from `rootpath`.
- `sitemap`, if enabled, will generate a `sitemap.xml` file at the root of the output directory. Requires
  `canonical_domain` to be set, since the sitemap is determined from canonical URLs.
- `sitemap_filename` can be used to override the default sitemap filename (`sitemap.xml`)
"""
function make(
    outdir,
    docs::Vector;
    assets_dir = nothing,
    brand_image::Union{Nothing,BrandImage} = nothing,
    custom_stylesheets = [],
    custom_scripts = [],
    search_engine = DEFAULT_ENGINE,
    prettyurls = true,
    rootpath = "/",
    hide_previews = true,
    canonical_domain::Union{AbstractString,Nothing} = nothing,
    sitemap::Bool = false,
    sitemap_filename::AbstractString = "sitemap.xml",
    # This keyword is for internal test use only:
    _override_windows_isinteractive_check::Bool = false,
)
    if Sys.iswindows() && !isinteractive()
        if _override_windows_isinteractive_check || isinteractive()
            @warn """
            Running a MultiDocumenter build interactively in Windows.
            This should only be used for development and testing, as it will lead to partial
            and broken builds. See https://github.com/JuliaComputing/MultiDocumenter.jl/issues/70
            """
        else
            msg = """
            MultiDocumenter deployments are disabled on Windows due to difficulties
            with handling symlinks in documentation sources.
            You _can_ test this build locally by running it interactively (i.e. in the REPL).
            See also: https://github.com/JuliaComputing/MultiDocumenter.jl/issues/70
            """
            error(msg)
        end
    end
    if isnothing(canonical_domain)
        (sitemap === true) &&
            throw(ArgumentError("When sitemap=true, canonical_domain must also be set"))
    else
        !isnothing(canonical_domain)
        if !startswith(canonical_domain, r"^https?://")
            throw(ArgumentError("""
            Invalid value for canonical_domain: $(canonical_domain)
            Must start with http:// or https://"""))
        end
        # We'll strip any trailing /-s though, in case the user passed something like
        # https://example.org/, because we want to concatenate the file paths with `/`
        canonical_domain = rstrip(canonical_domain, '/')
    end
    # We'll normalize rootpath to have /-s at the beginning and at the end, so that we
    # can assume that when concatenating this to other paths
    if !startswith(rootpath, "/")
        rootpath = string('/', rootpath)
    end
    if !endswith(rootpath, "/")
        rootpath = string(rootpath, '/')
    end
    site_root_url = string(canonical_domain, rstrip(rootpath, '/'))

    maybe_clone(flatten_dropdowncomponents(docs))

    dir = make_output_structure(
        flatten_dropdowncomponents(docs),
        prettyurls,
        hide_previews;
        canonical = site_root_url,
    )
    out_assets = joinpath(dir, "assets")
    if assets_dir !== nothing && isdir(assets_dir)
        cp(assets_dir, out_assets)
    end
    isdir(out_assets) || mkpath(out_assets)
    cp(joinpath(@__DIR__, "..", "assets", "default"), joinpath(out_assets, "default"))

    if search_engine != false
        if search_engine.engine == Stork && !Stork.has_stork()
            @warn "stork binary not found. Falling back to flexsearch as search_engine."
            search_engine = DEFAULT_ENGINE
        end
    end

    inject_styles_and_global_navigation(
        dir,
        docs,
        brand_image,
        custom_stylesheets,
        custom_scripts,
        search_engine,
        prettyurls,
        rootpath,
    )

    if search_engine != false
        search_engine.engine.build_search_index(
            dir,
            flatten_dropdowncomponents(docs),
            search_engine,
            rootpath,
        )
    end

    if sitemap
        make_sitemap(;
            sitemap_root = site_root_url,
            sitemap_filename,
            docs_root_directory = dir,
        )
    end

    cp(dir, outdir; force = true)
    rm(dir; force = true, recursive = true)

    return outdir
end

function flatten_dropdowncomponents(docs::Vector)
    out = DropdownComponent[]
    for doc in docs
        if doc isa DropdownComponent
            push!(out, doc)
        elseif doc isa MegaDropdownNav
            for col in doc.columns
                for doc in col.children
                    push!(out, doc)
                end
            end
        else
            for doc in doc.children
                push!(out, doc)
            end
        end
    end
    return out
end

function maybe_clone(docs::Vector)
    for doc in filter(x -> x isa MultiDocRef, docs)
        if !isdir(doc.upstream)
            if isempty(doc.giturl)
                error(
                    "MultiDocRef for $(doc.name): if giturl= is not passed, then upstream= must be an existing directory",
                )
            end
            @info "Upstream at $(doc.upstream) does not exist. `git clone`ing `$(doc.giturl)#$(doc.branch)`"
            run(
                `$(git()) clone --depth 1 $(doc.giturl) --branch $(doc.branch) --single-branch --no-tags $(doc.upstream)`,
            )
        else
            git_dir, git_worktree =
                abspath(joinpath(doc.upstream, ".git")), abspath(doc.upstream)
            if !isdir(git_dir)
                @warn "Unable to update existing clone at $(doc.upstream): .git/ directory missing"
                continue
            end
            @info "Updating existing clone at $(doc.upstream)"
            gitcmd = `$(git()) -C $(git_worktree) --git-dir=$(git_dir)`
            try
                if !success(`$(gitcmd) diff HEAD --exit-code`)
                    @warn "Existing clone at $(doc.upstream) has local changes -- not updating."
                    continue
                end
                run(`$(gitcmd) fetch origin $(doc.branch)`)
                run(`$(gitcmd) checkout --detach origin/$(doc.branch)`)
            catch e
                # We're only interested in catching `git` errors here
                isa(e, ProcessFailedException) || rethrow()
                @error "Unable to update existing clone at $(doc.upstream)" exception =
                    (e, catch_backtrace())
            end
        end
    end
    return nothing
end

function make_output_structure(
    docs::Vector{DropdownComponent},
    prettyurls,
    hide_previews;
    canonical::Union{AbstractString,Nothing},
)
    dir = mktempdir()

    for doc in Iterators.filter(x -> x isa MultiDocRef, docs)
        outpath = joinpath(dir, doc.path)

        mkpath(dirname(outpath))
        cp(doc.upstream, outpath; force = true)

        gitpath = joinpath(outpath, ".git")
        if isdir(gitpath)
            rm(gitpath, recursive = true)
        end

        previewpath = joinpath(outpath, "previews")
        if hide_previews && isdir(previewpath)
            rm(previewpath, recursive = true)
        end

        fix_canonical_url!(doc; canonical, root_dir = dir)
    end

    open(joinpath(dir, "index.html"), "w") do io
        println(
            io,
            """
                <!--This file is automatically generated by MultiDocumenter.jl-->
                <meta http-equiv="refresh" content="0; url=./$(string(first(docs).path, prettyurls ? "/" : "/index.html"))"/>
            """,
        )
    end

    return dir
end

function make_global_nav(
    dir,
    docs::Vector,
    thispagepath,
    brand_image,
    search_engine,
    prettyurls,
)
    nav = @htl """
    <nav id="multi-page-nav">
        $(render(brand_image, dir, thispagepath))
        <div id="nav-items" class="hidden-on-mobile">
            $([render(doc, dir, thispagepath, prettyurls) for doc in docs])
            $(search_engine.engine.render())
        </div>
        <button id="multidoc-toggler">
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path d="M3 6h18v2H3V6m0 5h18v2H3v-2m0 5h18v2H3v-2Z"></path>
            </svg>
        </button>
    </nav>
    """

    return htl_to_gumbo(nav)
end

function make_global_stylesheet(custom_stylesheets, path)
    out = []

    for stylesheet in custom_stylesheets
        stylesheet =
            startswith(stylesheet, r"https?://") ? stylesheet :
            replace(joinpath(path, stylesheet), raw"\\" => "/")
        style = Gumbo.HTMLElement{:link}(
            [],
            Gumbo.NullNode(),
            Dict("rel" => "stylesheet", "type" => "text/css", "href" => stylesheet),
        )
        push!(out, style)
    end

    return out
end

function make_global_scripts(custom_scripts, path)
    out = []

    for script in custom_scripts
        if script isa Docs.HTML
            js = Gumbo.HTMLElement{:script}(
                [],
                Gumbo.NullNode(),
                Dict("type" => "text/javascript", "charset" => "utf-8"),
            )
            push!(js, Gumbo.HTMLText(js, script.content))
            push!(out, js)
        elseif script isa AbstractString
            script =
                startswith(script, r"https?://") ? script :
                replace(joinpath(path, script), raw"\\" => "/")
            js = Gumbo.HTMLElement{:script}(
                [],
                Gumbo.NullNode(),
                Dict("src" => script, "type" => "text/javascript", "charset" => "utf-8"),
            )
            push!(out, js)
        else
            throw(
                ArgumentError(
                    "`custom_scripts` may only contain elements of type `AbstractString` or `Docs.HTML`.",
                ),
            )
        end
    end

    return out
end

function js_injector()
    return read(joinpath(@__DIR__, "..", "assets", "multidoc_injector.js"), String)
end


function inject_styles_and_global_navigation(
    dir,
    docs::Vector,
    brand_image,
    custom_stylesheets,
    custom_scripts,
    search_engine,
    prettyurls,
    rootpath,
)

    if search_engine != false
        search_engine.engine.inject_script!(custom_scripts, rootpath)
        search_engine.engine.inject_styles!(custom_stylesheets)
    end
    pushfirst!(custom_stylesheets, joinpath("assets", "default", "multidoc.css"))
    pushfirst!(custom_scripts, joinpath("assets", "default", "multidoc_injector.js"))

    @sync for (root, _, files) in walkdir(dir)
        for file in files
            path = joinpath(root, file)

            endswith(file, ".html") || continue

            islink(path) && continue
            isfile(path) || continue
            page = read(path, String)
            if startswith(
                page,
                "<!--This file is automatically generated by Documenter.jl-->",
            )
                continue
            end

            Threads.@spawn begin
                stylesheets = make_global_stylesheet(custom_stylesheets, relpath(dir, root))
                scripts = make_global_scripts(custom_scripts, relpath(dir, root))

                doc = Gumbo.parsehtml(page)
                injected = 0

                for el in AbstractTrees.PreOrderDFS(doc.root)
                    injected >= 2 && break

                    if el isa Gumbo.HTMLElement
                        if Gumbo.tag(el) == :head
                            for stylesheet in stylesheets
                                stylesheet.parent = el
                                push!(el.children, stylesheet)
                            end
                            for script in reverse!(scripts)
                                script.parent = el
                                pushfirst!(el.children, script)
                            end
                            injected += 1
                        elseif Gumbo.tag(el) == :body && !isempty(el.children)
                            documenter_div = first(el.children)
                            if documenter_div isa Gumbo.HTMLElement &&
                               Gumbo.getattr(documenter_div, "id", "") == "documenter"
                                @debug "Could not detect Documenter page layout in $path. This may be due to an old version of Documenter."
                            end
                            # inject global navigation as first element in body

                            global_nav = make_global_nav(
                                dir,
                                docs,
                                root,
                                brand_image,
                                search_engine,
                                prettyurls,
                            )
                            global_nav.parent = el
                            pushfirst!(el.children, global_nav)
                            injected += 1
                        end
                    end
                end

                open(path, "w") do io
                    print(io, doc)
                end
            end
        end
    end
end

end
