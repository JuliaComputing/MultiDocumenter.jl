# This files contains the functions used to implement the canonical URL
# update functionality.
function fix_canonical_url!(
        doc::MultiDocRef;
        canonical::Union{AbstractString, Nothing},
        root_dir::AbstractString,
    )
    # If the user didn't set `canonical`, then we don't need to do anything
    isnothing(canonical) && return
    # The user can also disable the canonical URL fixing on a per-package basis
    doc.fix_canonical_url || return
    # Determine the canonical URL and fix them in the HTML files
    documenter_directory_root = joinpath(root_dir, doc.path)
    try
        DocumenterTools.update_canonical_links(
            documenter_directory_root;
            canonical = join((canonical, doc.path), '/'),
        )
    catch e
        @error "Unable to update canonical URLs for this package" doc exception =
            (e, catch_backtrace())
    end

    return
end
