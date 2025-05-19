# This is vendored version of code that should eventually moved into DocumenterTools.jl
# once the generic interface has crystallized, and then DocumenterTools should be added
# as a dependency here.
#
# WIP upstream PR: https://github.com/JuliaDocs/DocumenterTools.jl/pull/78
#
# Note: these functions are not part of MultiDocumenter public API.

"""
    DocumenterTools.update_canonical_links_for_build(
        docs_directory::AbstractString;
        canonical::AbstractString,
    )

- **`canonical`**: corresponds to the `canonical` attribute of `Documenter.HTML`,
  specifying the root of the canonical URL.
"""
function update_canonical_links_for_version(
        docs_directory::AbstractString;
        canonical::AbstractString,
    )
    canonical = rstrip(canonical, '/')

    walkdocs(docs_directory, isdochtml) do fileinfo
        @debug "update_canonical_links: checking $(fileinfo.relpath)"
        # Determine the
        filepath = splitpath(fileinfo.relpath)
        new_canonical_href = if filepath[end] == "index.html"
            joinurl(canonical, filepath[1:(end - 1)]...) * '/'
        else
            joinurl(canonical, filepath[1:end]...)
        end

        html = Gumbo.parsehtml(read(fileinfo.fullpath, String))
        n_canonical_tags::Int = 0
        dom_updated::Bool = false
        for e in AbstractTrees.PreOrderDFS(html.root)
            is_canonical_element(e) || continue
            n_canonical_tags += 1
            canonical_href = Gumbo.getattr(e, "href", nothing)
            if canonical_href != new_canonical_href
                Gumbo.setattr!(e, "href", new_canonical_href)
                @debug "update_canonical_links_for_version: canonical_href updated" canonical_href new_canonical_href fileinfo.relpath
                dom_updated = true
            end
        end
        if n_canonical_tags == 0
            for e in AbstractTrees.PreOrderDFS(html.root)
                e isa Gumbo.HTMLElement || continue
                Gumbo.tag(e) == :head || continue
                canonical_href_element = Gumbo.HTMLElement{:link}(
                    [],
                    e,
                    Dict("rel" => "canonical", "href" => new_canonical_href),
                )
                push!(e.children, canonical_href_element)
                @debug "update_canonical_links_for_version: added new canonical_href" new_canonical_href fileinfo.relpath
                dom_updated = true
                break
            end
        end
        if dom_updated
            open(io -> print(io, html), fileinfo.fullpath, "w")
        end
        if n_canonical_tags > 1
            @error "Multiple canonical tags!" file = fileinfo.relpath
        end
    end
    return nothing
end

is_canonical_element(e) =
    (e isa Gumbo.HTMLElement) &&
    (Gumbo.tag(e) == :link) &&
    (Gumbo.getattr(e, "rel", nothing) == "canonical")
joinurl(ps::AbstractString...) = join(ps, '/')

"""
Takes the multi-versioned Documenter site in `docs_directory` and updates the HTML canonical URLs
to point to `canonical`.
"""
function update_canonical_links(docs_directory::AbstractString; canonical::AbstractString)
    canonical = rstrip(canonical, '/')
    docs_directory = abspath(docs_directory)
    isdir(docs_directory) || throw(ArgumentError("No such directory: $(docs_directory)"))

    canonical_path = canonical_directory_from_redirect_index_html(docs_directory)
    if isnothing(canonical_path)
        # canonical_version_from_versions_js returns just a string, but we want to splat
        # canonical_path later, so we turn this into a single-element tuple
        canonical_path = (canonical_version_from_versions_js(docs_directory),)
    end
    canonical_full_root = joinurl(canonical, canonical_path...)
    # If we have determined which version should be the canonical version, we can actually
    # go and run update_canonical_links_for_version on each directory. First, we'll gather
    # up the list of Documenter (or other) directories we actually want to run over.
    docs_subdirectory_queue, docs_subdirectories = readdir(docs_directory), []
    while !isempty(docs_subdirectory_queue)
        docs_subdirectory = popfirst!(docs_subdirectory_queue)
        path = joinpath(docs_directory, docs_subdirectory)
        # We'll skip all files. This includes files such as index.html, which in this
        # directory will likely be the redirect. Also, links should be pointing to other
        # versions, so we'll skip them too.
        # Note: we need to check islink() first, because on windows, calling isdir() on a
        # symlink can make it throw a permissions IOError.
        if islink(path) || !isdir(path)
            continue
        end
        # Preview directory is should contain other Documenter directories, so we just add
        # the subdirectories into the queue and ignore the parent directory itself
        if docs_subdirectory == "previews"
            append!(docs_subdirectory_queue, joinpath.(docs_subdirectory, readdir(path)))
            continue
        end
        # For other directories, we check for the presence of siteinfo.js, and warn if that
        # is missing (but we still try to go and update the canonical URLs).
        if !isfile(joinpath(path, "siteinfo.js"))
            @warn "update_canonical_links: missing siteinfo.js file" path
        end
        push!(docs_subdirectories, path)
    end
    # Finally, we can run update_canonical_links_for_version on the directory.
    for path in docs_subdirectories
        @debug "Updating canonical URLs for a version" path canonical_full_root
        update_canonical_links_for_version(path; canonical = canonical_full_root)
    end
    return nothing
end

function canonical_directory_from_redirect_index_html(docs_directory::AbstractString)
    redirect_index_html_path = joinpath(docs_directory, "index.html")
    isfile(redirect_index_html_path) || return nothing
    redirect_url = get_meta_redirect_url(redirect_index_html_path)
    isnothing(redirect_url) && return nothing
    return splitpath(normpath(redirect_url))
end

"""
Parses the HTML file at `indexhtml_path` and tries to extract the `url=...` value
of the redirect `<meta http-equiv="refresh" ...>` tag.
"""
get_meta_redirect_url(indexhtml_path::AbstractString) =
    get_meta_redirect_url(Gumbo.parsehtml(read(indexhtml_path, String)))

function get_meta_redirect_url(html::Gumbo.HTMLDocument)
    for e in AbstractTrees.PreOrderDFS(html.root)
        e isa Gumbo.HTMLElement || continue
        Gumbo.tag(e) == :meta || continue
        Gumbo.getattr(e, "http-equiv", nothing) == "refresh" || continue
        content = Gumbo.getattr(e, "content", nothing)
        if isnothing(content)
            @warn "<meta http-equiv=\"refresh\" ...> with no content attribute" path =
                indexhtml_path
            continue
        end
        m = match(r"[0-9]+;\s*url=(.*)", content)
        if isnothing(m)
            @warn "Unable to parse content value of <meta http-equiv=\"refresh\" ...>" content path =
                indexhtml_path
            continue
        end
        return m.captures[1]
    end
    return nothing
end

function canonical_version_from_versions_js(docs_directory)
    isdir(docs_directory) || throw(ArgumentError("Not a directory: $(docs_directory)"))
    # Try to extract the list of versions from versions.js
    versions_js = joinpath(docs_directory, "versions.js")
    isfile(versions_js) ||
        throw(ArgumentError("versions.js is missing in $(docs_directory)"))
    versions = map(extract_versions_list(versions_js)) do version_str
        isversion, version_number = if occursin(Base.VERSION_REGEX, version_str)
            true, VersionNumber(version_str)
        else
            false, nothing
        end
        fullpath = joinpath(docs_directory, version_str)
        return (;
            path = version_str,
            path_exists = isdir(fullpath) || islink(fullpath),
            symlink = islink(fullpath),
            isversion,
            version_number,
            fullpath,
        )
    end
    # We'll filter out a couple of potential bad cases and issue warnings
    filter(versions) do vi
        if !vi.path_exists
            @warn "update_canonical_links: path does not exist or is not a directory" docs_directory vi
            return false
        end
        return true
    end
    # We need to determine the canonical path. This would usually be something like the stable/
    # directory, but it can have a different name, including being a version number. So first we
    # try to find a non-version directory _that is a symlink_ (so that it wouldn't get confused)
    # previews/ or dev builds. If that fails, we try to find the directory matching `v[0-9]+`,
    # with the highest version number. This does not cover all possible cases, but should be good
    # enough for now.
    if isempty(versions)
        error("Unable to determine the canonical path. Found no version directories")
    end
    non_version_symlinks = filter(vi -> !vi.isversion && vi.symlink, versions)
    canonical_version = if isempty(non_version_symlinks)
        # We didn't find any non-version symlinks, so we'll try to find the vN directory now
        # as a fallback.
        version_symlinks = map(versions) do vi
            m = match(r"^v([0-9]+)$", vi.path)
            isnothing(m) && return nothing
            parse(Int, m[1]) => vi
        end
        filter!(!isnothing, version_symlinks)
        if isempty(version_symlinks)
            error("Unable to determine the canonical path. Found no version directories")
        end
        # Note: findmax(first, version_symlinks) would be nicer, but is not supported
        # on Julia 1.6
        _, idx = findmax(first.(version_symlinks))
        version_symlinks[idx][2]
    elseif length(non_version_symlinks) > 1
        error(
            "Unable to determine the canonical path. Found multiple non-version symlinks.\n$(non_version_symlinks)",
        )
    else
        only(non_version_symlinks)
    end

    return canonical_version.path
end

function extract_versions_list(versions_js::AbstractString)
    versions_js = abspath(versions_js)
    isfile(versions_js) || throw(ArgumentError("No such file: $(versions_js)"))
    versions_js_content = read(versions_js, String)
    m = match(r"var\s+DOC_VERSIONS\s*=\s*\[([0-9A-Za-z\"\s.,+-]+)\]", versions_js_content)
    if isnothing(m)
        throw(
            ArgumentError(
                """
                Could not find DOC_VERSIONS in $(versions_js):
                $(versions_js_content)
                """
            )
        )
    end
    versions = strip.(c -> isspace(c) || (c == '"'), split(m[1], ","))
    filter!(!isempty, versions)
    if isempty(versions)
        throw(
            ArgumentError(
                """
                DOC_VERSIONS empty in $(versions_js):
                $(versions_js_content)
                """
            )
        )
    end
    return versions
end
