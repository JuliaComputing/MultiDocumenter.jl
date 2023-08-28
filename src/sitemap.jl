# Note: Franklin.jl also implements sitemap generation:
#
#   https://github.com/tlienart/Franklin.jl/blob/f1f7d044dc95ba0d9f368a3d1afc233eb58a59cf/src/manager/sitemap_generator.jl#L51
#
# At some point it might be worth factoring the code into a small shared package.
# Franklin's implementation is more general that this here, but it looks like it relies
# of Franklin-specific globals, so it's not a trivial copy-paste into a separate package.

const SITEMAP_URL_LIMIT = 50_000
const SITEMAP_SIZE_LIMIT = 52_428_800

function make_sitemap(;
    sitemap_filename::AbstractString,
    sitemap_root::AbstractString,
    docs_root_directory::AbstractString,
)
    # Determine the list of sitemap URLs by finding all canonical URLs
    sitemap_urls = find_sitemap_urls(; docs_root_directory, sitemap_root)
    if length(sitemap_urls) == 0
        @error "No sitemap URLs found"
        return
    end

    sitemap_buffer = IOBuffer()
    write(
        sitemap_buffer,
        """
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
""",
    )
    for loc in sort(sitemap_urls)
        write(sitemap_buffer, "<url><loc>$(loc)</loc></url>\n")
    end
    write(sitemap_buffer, "</urlset>\n")

    # Sitemaps are limited to 50 000 URLs: https://www.sitemaps.org/protocol.html#index
    # TODO: we could automatically split the sitemap up if it's bigger than that and
    # generate a sitemap index.
    if length(sitemap_urls) > SITEMAP_URL_LIMIT
        @warn "Sitemap file has too many items: $(length(canonical_urls)) (limit: $(SITEMAP_URL_LIMIT))"
    end
    sitemap_bytes = take!(sitemap_buffer)
    if length(sitemap_bytes) > SITEMAP_SIZE_LIMIT
        @warn "Sitemap is too large: $(length(sitemap_bytes)) bytes (limit: $(SITEMAP_SIZE_LIMIT))"
    end

    # Write the actual sitemap.xml file into the output directory
    write(joinpath(docs_root_directory, sitemap_filename), sitemap_bytes)
end

function find_sitemap_urls(;
    docs_root_directory::AbstractString,
    sitemap_root::AbstractString,
)
    # On Windows, .relpath should have \ as path separators, which we have to
    # "normalize" to /-s for web
    canonical_urls = String[]
    DocumenterTools.walkdocs(docs_root_directory, DocumenterTools.isdochtml) do fileinfo
        html = Gumbo.parsehtml(read(fileinfo.fullpath, String))
        canonical_href = find_canonical_url(html; filepath = fileinfo.fullpath)
        if isnothing(canonical_href)
            # A common case for why the canonical URL would be missing is when it's a redirect
            # HTML file, and that is fine. So we check for that and only warn if it is _not_
            # a redirect file.
            if DocumenterTools.get_meta_redirect_url(html) === nothing
                @warn "Canonical URL missing: $(fileinfo.relpath)"
            end
            return
        end
        # Check that the canonincal URL is correct.
        # First, we check that the root part is actually what we expect it to be.
        if !startswith(canonical_href, sitemap_root)
            @warn "Invalid canonical URL, excluded from sitemap." canonical_href fileinfo.fullpath
            return
        end
        # Let's make sure we're not adding duplicates, but first we must normalize the URL
        canonical_href = normalize_canonical_url(canonical_href)
        if !(canonical_href in canonical_urls)
            push!(canonical_urls, canonical_href)
        end
    end
    return canonical_urls
end

# foo/bar, foo/bar/ and foo/bar/index.html are basically equivalent, so we normalize the canonical
# URL to foo/bar/
normalize_canonical_url(url::AbstractString) = replace(url, r"/(index\.html)?$" => "/")

# Loops through a Gumbo-parsed DOM tree
function find_canonical_url(html::Gumbo.HTMLDocument; filepath::AbstractString)
    canonical_href = nothing
    for e in AbstractTrees.PreOrderDFS(html.root)
        e isa Gumbo.HTMLElement || continue
        Gumbo.tag(e) == :link || continue
        Gumbo.getattr(e, "rel", nothing) == "canonical" || continue
        if isnothing(canonical_href)
            canonical_href = Gumbo.getattr(e, "href", nothing)
        else
            @warn "Duplicate <link rel=\"canonical\" ...> tag. Ignoring." filepath e canonical_href
        end
    end
    return canonical_href
end
