render(::Nothing, args...) = nothing

function render(brand_image::BrandImage, dir, thispagepath)
    return @htl """
    <a class="brand" href="$(relpath(joinpath(dir, brand_image.path), thispagepath))">
        <img src="$(relpath(joinpath(dir, brand_image.imagepath), thispagepath))" alt="home">
    </a>"""
end

function render(doc::MultiDocRef, dir, thispagepath, prettyurls)
    path = joinpath(dir, doc.path)
    if !isfile(joinpath(path, "index.html"))
        stable = joinpath(path, "stable")
        dev = joinpath(path, "dev")
        if isfile(joinpath(stable, "index.html"))
            path = stable
        elseif isfile(joinpath(dev, "index.html"))
            path = dev
        end
    end
    rp = relpath(path, thispagepath)
    href = string(rp, prettyurls ? "/" : "/index.html")
    # need to force a trailing pathsep here
    class = startswith(thispagepath, joinpath(dir, doc.path, "")) ?
        "nav-link active nav-item" : "nav-link nav-item"

    return @htl """
    <a href="$href" class="$class">$(doc.name)</a>
    """
end

function render(doc::DropdownNav, dir, thispagepath, prettyurls)
    return @htl """
    <div class="nav-dropown">
        <span class="nav-item dropdown-label">$(doc.name)</span>
        <ul class="nav-dropdown-container">
            $([render(doc, dir, thispagepath, prettyurls) for doc in doc.children])
        </ul>
    </div>
    """
end

function render(doc::MegaDropdownNav, dir, thispagepath, prettyurls)
    return @htl """
    <div class="nav-dropown">
        <span class="nav-item dropdown-label">$(doc.name)</span>
        <div class="nav-dropdown-container nav-mega-dropdown-container">
            $([render(doc, dir, thispagepath, prettyurls) for doc in doc.columns])
        </div>
    </div>
    """
end

function render(doc::Column, dir, thispagepath, prettyurls)
    return @htl """
    <div class="nav-mega-column">
        <h5 class="column-header">$(doc.name)</h5>
        <ul class="column-content">
            $([render(doc, dir, thispagepath, prettyurls) for doc in doc.children])
        </ul>
    </div>
    """
end

htl_to_gumbo(htl) = Gumbo.parsehtml(sprint(show, htl)).root.children[2].children[1]
