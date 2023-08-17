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
    # We'll use join(..., '/') below to join the path, so we need to remove the
    # trailing / here.
    sitemap_root = rstrip(sitemap_root, '/')

    sitemap_buffer = IOBuffer()
    write(sitemap_buffer, """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    """)
    nitems = 0
    walkdocs(docs_root_directory) do fileinfo
        # On Windows, .relpath should have \ as path separators, which we have to
        # "normalize" to /-s for web
        loc = join((sitemap_root, splitpath(fileinfo.relpath)...), '/')
        write(sitemap_buffer, "<url><loc>$(loc)</loc></url>\n")
        nitems += 1
    end
    write(sitemap_buffer, "</urlset>\n")

    # Sitemaps are limuited to 50 000 URLs: https://www.sitemaps.org/protocol.html#index
    # TODO: we could automatically split the sitemap up if it's bigger than that and
    # generate a sitemap index.
    if nitems > SITEMAP_URL_LIMIT
        @warn "Sitemap file has too many items: $(nitems) (limit: $(SITEMAP_URL_LIMIT))"
    end
    sitemap_bytes = take!(sitemap_buffer)
    if length(sitemap_bytes) > SITEMAP_SIZE_LIMIT
        @warn "Sitemap is too large: $(length(sitemap_bytes)) bytes (limit: $(SITEMAP_SIZE_LIMIT))"
    end

    # Write the actual sitemap.xml file into the output directory
    write(joinpath(docs_root_directory, sitemap_filename), sitemap_bytes)
end
