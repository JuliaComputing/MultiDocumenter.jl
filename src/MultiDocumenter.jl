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
    SearchConfig(index_versions = ["stable"], engine = MultiDocumenter.PageFind, lowfi = false)

`index_versions` is a vector of relative paths used for generating the search index. Only
the first matching path is considered (except for `PageFind`, which indexes all of them).
This is one global list, so a `MultiDocRef` that publishes none of these paths -- e.g.
because its [`VersionSelection`](@ref) keeps different ones -- contributes nothing to the
search index; MultiDocumenter warns about each such ref during the build.
`engine` may be `MultiDocumenter.PageFind`, `MultiDocumenter.FlexSearch`, `MultiDocumenter.Stork`,
or a module that conforms to the expected API (which is currently undocumented).
`lowfi = true` will try to minimize search index size. Only relevant for flexsearch.
"""
Base.@kwdef mutable struct SearchConfig
    index_versions = ["stable", "dev"]
    engine = PageFind
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
    struct VersionSelection
    VersionSelection(versions; all_versions_url = nothing)

Selects which deployed versions of a [`MultiDocRef`](@ref) are copied into the aggregate,
and where the ones that are left out can still be found.

Aggregating packages with long `gh-pages` histories can push the combined site past a host's
size limit (GitHub Pages allows 1 GB), and most of that history is rarely read. Copying only
`["stable", "dev"]` keeps the site small; `all_versions_url` then keeps the rest reachable.

* `versions`: the version directories to copy, e.g. `["stable", "dev"]`. Entries that do not
  exist upstream are reported and skipped; if none of them exist, all versions are copied
  instead. The **first** version that was copied is what the ref's `index.html` redirects to
  and what MultiDocumenter treats as canonical, so the order matters.
* `all_versions_url`: absolute http(s) URL of the upstream documentation site *root*, e.g.
  `https://org.github.io/Pkg.jl/`. When given, a "See All Versions" entry pointing there is
  added to the version selector. Use the site root rather than a specific version:
  Documenter's selector tries to stay on the equivalent page, so it may append the current
  page's path to this URL.

```julia
MultiDocumenter.VersionSelection(
    ["stable", "dev"];
    all_versions_url = "https://org.github.io/Pkg.jl/",
)
```
"""
struct VersionSelection
    versions::Vector{String}
    all_versions_url::Union{String, Nothing}

    function VersionSelection(
            versions::AbstractVector{<:AbstractString};
            all_versions_url::Union{AbstractString, Nothing} = nothing,
        )
        isempty(versions) && throw(
            ArgumentError("VersionSelection: `versions` must name at least one version")
        )
        if all_versions_url !== nothing
            # A relative URL would point back into the aggregate, which is precisely where
            # the versions we did not copy are not.
            startswith(all_versions_url, "http://") ||
                startswith(all_versions_url, "https://") ||
                throw(
                ArgumentError(
                    "VersionSelection: `all_versions_url` must be an absolute http(s) URL, got $(repr(all_versions_url))"
                )
            )
        end
        return new(
            collect(String, versions),
            all_versions_url === nothing ? nothing : String(all_versions_url),
        )
    end
end

VersionSelection(version::AbstractString; kwargs...) =
    VersionSelection([version]; kwargs...)

"""
    struct MultiDocRef <: DropdownComponent
    MultiDocRef(; upstream, name, path, giturl = "", branch = "gh-pages", fix_canonical_url = true, versions = nothing)

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
* `versions`: a [`VersionSelection`](@ref), to copy only some of the deployed versions
  instead of the whole `upstream` tree. All versions are copied by default. Root files (e.g.
  `index.html`, `versions.js`) are always copied. When a selection is given, `versions.js` is
  rewritten to list only the copied versions, and `DOCUMENTER_NEWEST` / `DOCUMENTER_STABLE`
  are repointed at copied versions so that Documenter does not mark kept pages as outdated
  (and `noindex`) or link its banner at a version that is no longer there.
"""
struct MultiDocRef <: DropdownComponent
    upstream::String
    path::String
    name::Any
    fix_canonical_url::Bool
    giturl::String
    branch::String
    versions::Union{VersionSelection, Nothing}
end

# so that positional construction keeps working as it did before `versions` was added
MultiDocRef(upstream, path, name, fix_canonical_url, giturl, branch) =
    MultiDocRef(upstream, path, name, fix_canonical_url, giturl, branch, nothing)

function MultiDocRef(;
        upstream,
        name,
        path,
        giturl = "",
        branch = "gh-pages",
        fix_canonical_url = true,
        versions::Union{VersionSelection, Nothing} = nothing,
    )
    return MultiDocRef(upstream, path, name, fix_canonical_url, giturl, branch, versions)
end

"""
    Link([text::String], link::String, [isexternal::Bool]) <: DropdownComponent

Represents a link to an external site.
"""
struct Link <: MultiDocumenter.DropdownComponent
    text::String
    link::String
    isexternal::Bool
end

Link(link::String) = Link(link, link)
Link(text::String, link::String) = Link(text, link, contains(link, "//"))

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

"""
Warn about any [`MultiDocRef`](@ref) that will contribute nothing to the search index.

`SearchConfig.index_versions` is a single global list, but each ref decides for itself which
versions it publishes (see [`VersionSelection`](@ref)), so a ref can easily end up with none
of the indexed version directories in its output. Its pages are then published and linked
from the navigation, but unreachable through the search box -- which is easy to miss, since
nothing else about the build looks wrong.
"""
function warn_unindexed_refs(root, docs::Vector, index_versions::AbstractVector)
    for ref in filter(x -> x isa MultiDocRef, docs)
        refroot = joinpath(root, ref.path)
        isdir(refroot) || continue
        any(dir -> isdir(joinpath(refroot, dir)), index_versions) && continue
        @warn(
            "None of this package's pages will be searchable: it publishes none of the " *
                "indexed versions. Add one of the versions it does publish to " *
                "SearchConfig(index_versions = ...).",
            path = ref.path,
            index_versions,
            published = filter(d -> isdir(joinpath(refroot, d)), readdir(refroot)),
        )
    end
    return nothing
end

function walk_outputs(f, root, docs::Vector, dirs::Vector{String})
    warn_unindexed_refs(root, docs, dirs)
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
    return nothing
end

include("renderers.jl")
include("search/pagefind.jl")
include("search/flexsearch.jl")
include("search/stork.jl")
include("canonical.jl")
include("sitemap.jl")

const DEFAULT_ENGINE = SearchConfig(; index_versions = ["stable", "dev"], engine = PageFind)

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
        brand_image::Union{Nothing, BrandImage} = nothing,
        custom_stylesheets = [],
        custom_scripts = [],
        search_engine = DEFAULT_ENGINE,
        prettyurls = true,
        rootpath = "/",
        hide_previews = true,
        canonical_domain::Union{AbstractString, Nothing} = nothing,
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
            throw(
                ArgumentError(
                    """
                    Invalid value for canonical_domain: $(canonical_domain)
                    Must start with http:// or https://"""
                )
            )
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

# --- VersionSelection: copy only selected version dirs and link to the full upstream site ---

const SEE_ALL_VERSIONS_LABEL = "See All Versions"

const GENERATED_REDIRECT_MARKER = "<!--This file is automatically generated by MultiDocumenter.jl-->"

"""
Whether `page` is a generated redirect stub rather than a rendered documentation page.

Injecting stylesheets and scripts into these would make a page whose only job is to redirect
first fetch and run the whole aggregate front end, and would destroy the marker itself.
"""
is_generated_redirect(page::AbstractString) =
    startswith(page, "<!--This file is automatically generated by Documenter.jl-->") ||
    startswith(page, GENERATED_REDIRECT_MARKER)

"""
Copy all root files and the listed version directories from `src` to `dst`, skipping `.git`
and any version directory not in `versions`.

Returns the subset of `versions` that was actually copied, in the given order. Requested
versions that are missing upstream, or are symlinks with no target left (which happens on
`gh-pages` branches where old version directories were pruned by hand), are reported and
skipped rather than aborting the build.

Everything is copied with `follow_symlinks = true`, so that e.g. `stable -> v5.5.0` becomes
a real directory and the result does not depend on paths that were not copied.
"""
function cp_select_versions(src::String, dst::String, versions::Vector{String})
    mkpath(dst)
    verset = Set(versions)
    copied, dangling = String[], String[]
    for entry in readdir(src)
        entry == ".git" && continue
        full = joinpath(src, entry)
        if islink(full) && !ispath(full)
            # ispath() follows the link, so this is a link whose target is gone
            entry in verset && push!(dangling, entry)
        elseif isfile(full)
            cp(full, joinpath(dst, entry); force = true, follow_symlinks = true)
        elseif isdir(full) && entry in verset
            cp(full, joinpath(dst, entry); force = true, follow_symlinks = true)
            push!(copied, entry)
        end
    end
    isempty(dangling) || @warn "Skipping version directories whose symlink target is missing" src dangling
    # dangling ones are already reported above, with a more specific reason
    missing_versions = filter(v -> v ∉ copied && v ∉ dangling, versions)
    isempty(missing_versions) ||
        @warn "Some selected versions do not exist upstream and were skipped" src missing_versions
    # preserve the caller's ordering: it decides which version the ref lands on
    copiedset = Set(copied)
    return filter(in(copiedset), versions)
end

"""The version a copied version directory holds, as recorded in its `siteinfo.js`."""
function version_of_directory(outpath::AbstractString, dir::AbstractString)
    siteinfo = joinpath(outpath, dir, "siteinfo.js")
    isfile(siteinfo) || return nothing
    m = match(r"var\s+DOCUMENTER_CURRENT_VERSION\s*=\s*\"(.*?)\"", read(siteinfo, String))
    return isnothing(m) ? nothing : m[1]
end

"""
Rewrite `versions.js` so that the version selector only offers `kept_versions`, and so that
`DOCUMENTER_NEWEST` names the newest version we kept.

`DOCUMENTER_NEWEST` matters because Documenter's `warner.js` compares it against each
directory's `DOCUMENTER_CURRENT_VERSION` and, on a mismatch, marks the page `noindex` and
shows an "older version" banner. Left pointing at a version that was not copied, that
de-indexes perfectly current pages.
"""
function rewrite_versions_js(outpath::String, kept_versions::Vector{String})
    vjs = joinpath(outpath, "versions.js")
    isfile(vjs) || return nothing
    content = read(vjs, String)
    new_list = "[\n    \"" * join(kept_versions, "\",\n    \"") * "\"\n]"
    content = replace(
        content,
        r"var\s+DOC_VERSIONS\s*=\s*\[[\s\S]*?\]" => "var DOC_VERSIONS = " * new_list,
    )
    newest = newest_kept_version(outpath, kept_versions)
    if newest !== nothing
        content = replace(
            content,
            r"var\s+DOCUMENTER_NEWEST\s*=\s*\"(.*?)\"" => "var DOCUMENTER_NEWEST = \"$(newest)\"",
        )
    end
    write(vjs, content)
    return nothing
end

"""
The highest version number among the copied version directories, or `nothing` if none of
them holds a release (e.g. only `dev` was kept, which never triggers the banner anyway).
"""
function newest_kept_version(outpath::AbstractString, kept_versions::Vector{String})
    newest = nothing
    for dir in kept_versions
        version = version_of_directory(outpath, dir)
        version === nothing && continue
        occursin(Base.VERSION_REGEX, version) || continue
        parsed = tryparse(VersionNumber, version)
        parsed === nothing && continue
        if newest === nothing || parsed > newest[2]
            newest = (version, parsed)
        end
    end
    return newest === nothing ? nothing : newest[1]
end

"""The copied directory that `DOCUMENTER_STABLE` should point at, if we can name one."""
function stable_target(outpath::AbstractString, kept_versions::Vector{String})
    "stable" in kept_versions && return "stable"
    newest = newest_kept_version(outpath, kept_versions)
    newest === nothing && return nothing
    for dir in kept_versions
        version_of_directory(outpath, dir) == newest && return dir
    end
    return nothing
end

"""
Point `DOCUMENTER_STABLE` in each copied `siteinfo.js` at a directory that still exists.

Documenter's "older version" banner links to `../\$(DOCUMENTER_STABLE)`, which 404s if the
stable directory was not among the copied versions.
"""
function rewrite_stable_target!(outpath::String, kept_versions::Vector{String})
    target = stable_target(outpath, kept_versions)
    target === nothing && return nothing
    for dir in kept_versions
        siteinfo = joinpath(outpath, dir, "siteinfo.js")
        isfile(siteinfo) || continue
        content = read(siteinfo, String)
        new_content = replace(
            content,
            r"var\s+DOCUMENTER_STABLE\s*=\s*\"(.*?)\"" => "var DOCUMENTER_STABLE = \"$(target)\"",
        )
        new_content == content || write(siteinfo, new_content)
    end
    return nothing
end

"""
Map the output subdirectory of each version-limited `MultiDocRef` to its "See All Versions"
URL. Refs that copy all their versions get no entry: the point of the link is to reach the
versions that were left out, and there are none.
"""
function see_all_versions_urls(docs::Vector)
    urls = Dict{Vector{String}, String}()
    for doc in Iterators.filter(x -> x isa MultiDocRef, flatten_dropdowncomponents(docs))
        doc.versions === nothing && continue
        url = doc.versions.all_versions_url
        url === nothing && continue
        urls[splitpath(doc.path)] = url
    end
    return urls
end

"""
The "See All Versions" URL that applies to the page at `relative_path`, if any.

At most one ref can match: two refs whose paths nest would copy over each other in
[`make_output_structure`](@ref) to begin with.
"""
function see_all_versions_url_for(urls::Dict{Vector{String}, String}, relative_path::AbstractString)
    isempty(urls) && return nothing
    parts = splitpath(relative_path)
    for (docpath, url) in urls
        n = length(docpath)
        # the page has to live *below* the ref's directory, not be the directory itself
        n < length(parts) && view(parts, 1:n) == docpath && return url
    end
    return nothing
end

"""
Add a "See All Versions" entry to Documenter's version selector, pointing at `url`.

Documenter's own selector code (`assets/html/js/versions.js`) only ever appends to the
selector -- it never clears it, and it matches the versions from `DOC_VERSIONS` against
existing options by their text. So an `<option>` written in at build time survives
untouched and needs no client side code; it ends up above the versions Documenter fills in.

Selecting it hands over to Documenter's own handler, which tries to stay on the same page:
it appends the current path below the version directory to `url`, `HEAD`s that, and falls
back to `url` itself if the probe fails. `url` should therefore name a site root -- point it
at a specific version and a visitor of `.../stable/man/guide.html` may well land on
`.../<that version>/man/guide.html` instead of the page you meant.

Pages without a version selector (e.g. the redirect stubs) are left alone.
"""
function inject_see_all_versions_option!(html::Gumbo.HTMLDocument, url::AbstractString)
    for el in AbstractTrees.PreOrderDFS(html.root)
        el isa Gumbo.HTMLElement || continue
        Gumbo.tag(el) == :select || continue
        Gumbo.getattr(el, "id", "") == "documenter-version-selector" || continue
        option = Gumbo.HTMLElement{:option}([], el, Dict("value" => url))
        push!(option.children, Gumbo.HTMLText(option, SEE_ALL_VERSIONS_LABEL))
        push!(el.children, option)
        break
    end
    return nothing
end

function make_output_structure(
        docs::Vector{DropdownComponent},
        prettyurls,
        hide_previews;
        canonical::Union{AbstractString, Nothing},
    )
    dir = mktempdir()

    for doc in Iterators.filter(x -> x isa MultiDocRef, docs)
        outpath = joinpath(dir, doc.path)

        mkpath(dirname(outpath))
        if doc.versions !== nothing
            kept_versions = cp_select_versions(doc.upstream, outpath, doc.versions.versions)
            if isempty(kept_versions)
                # A limited copy would leave a ref that only 404s, so fall back to copying
                # everything -- what happens without a VersionSelection -- rather than
                # publishing a broken entry.
                @warn "None of the selected versions exist upstream; copying all versions instead" doc.path doc.versions.versions
                rm(outpath; force = true, recursive = true)
                cp(doc.upstream, outpath; force = true)
            else
                # Overwrite the root index.html so we never serve the clone's redirect (it
                # may point at an old org URL, or at a version we did not copy). The first
                # kept version wins, so the order of the selection decides where the ref
                # lands, and which version fix_canonical_url! treats as canonical.
                open(joinpath(outpath, "index.html"), "w") do io
                    println(io, GENERATED_REDIRECT_MARKER)
                    println(io, "<meta http-equiv=\"refresh\" content=\"0; url=./$(first(kept_versions))/\"/>")
                end
                rewrite_versions_js(outpath, kept_versions)
                rewrite_stable_target!(outpath, kept_versions)
                if !hide_previews
                    # cp_select_versions only copies the requested versions, so previews
                    # have to be brought over separately to honour hide_previews = false.
                    previews = joinpath(doc.upstream, "previews")
                    isdir(previews) && cp(
                        previews, joinpath(outpath, "previews");
                        force = true, follow_symlinks = true,
                    )
                end
            end
        else
            cp(doc.upstream, outpath; force = true)
        end

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
        println(io, GENERATED_REDIRECT_MARKER)
        println(
            io,
            """<meta http-equiv="refresh" content="0; url=./$(string(first(docs).path, prettyurls ? "/" : "/index.html"))"/>""",
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

    all_versions_urls = see_all_versions_urls(docs)

    @sync for (root, _, files) in walkdir(dir)
        for file in files
            path = joinpath(root, file)

            endswith(file, ".html") || continue

            islink(path) && continue
            isfile(path) || continue
            page = read(path, String)
            is_generated_redirect(page) && continue

            Threads.@spawn begin
                stylesheets = make_global_stylesheet(custom_stylesheets, relpath(dir, root))
                scripts = make_global_scripts(custom_scripts, relpath(dir, root))

                doc = Gumbo.parsehtml(page)

                all_versions_url =
                    see_all_versions_url_for(all_versions_urls, relpath(path, dir))
                if all_versions_url !== nothing
                    inject_see_all_versions_option!(doc, all_versions_url)
                end

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

    return nothing
end

end
