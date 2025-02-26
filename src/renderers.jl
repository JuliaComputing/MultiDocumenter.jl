render(::Nothing, args...) = nothing

function render(brand_image::BrandImage, dir, thispagepath)
    href =
        startswith(brand_image.path, r"https?://") ? brand_image.path :
        relpath(joinpath(dir, brand_image.path), thispagepath)
    src =
        startswith(brand_image.imagepath, r"https?://") ? brand_image.imagepath :
        relpath(joinpath(dir, brand_image.imagepath), thispagepath)
    return @htl """
    <a class="brand" href="$(href)">
        <img src="$(src)" alt="home">
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
    class =
        startswith(thispagepath, joinpath(dir, doc.path, "")) ? "nav-link active nav-item" :
        "nav-link nav-item"

    return @htl """
    <a href="$href" class="$class">$(doc.name)</a>
    """
end

function render(c::Link, doc, thispage, prettyurls)
    # class nav-link nav-item makes the formatting correct
    # target="_blank" opens the link in a new tab
    # TODO: add "external link" icon after, either chain or arrow exiting box.
    # TODO: allow internal links
    return @htl """
    <a href=$(c.link) class="nav-link nav-item" target="_blank">$(c.text)</a>
    """
end

function render(doc::DropdownNav, dir, thispagepath, prettyurls)
    return @htl """
    <div class="nav-dropdown">
        <button class="nav-item dropdown-label">$(doc.name)</button>
        <ul class="nav-dropdown-container">
            $([render(doc, dir, thispagepath, prettyurls) for doc in doc.children])
        </ul>
    </div>
    """
end

function render(doc::MegaDropdownNav, dir, thispagepath, prettyurls)
    return @htl """
    <div class="nav-dropdown">
        <button class="nav-item dropdown-label">$(doc.name)</button>
        <div class="nav-dropdown-container nav-mega-dropdown-container">
            $([render(doc, dir, thispagepath, prettyurls) for doc in doc.columns])
        </div>
    </div>
    """
end

function render(doc::Column, dir, thispagepath, prettyurls)
    return @htl """
    <div class="nav-mega-column">
        <div class="column-header">$(doc.name)</div>
        <ul class="column-content">
            $([render(doc, dir, thispagepath, prettyurls) for doc in doc.children])
        </ul>
    </div>
    """
end

htl_to_gumbo(htl) = Gumbo.parsehtml(sprint(show, htl)).root.children[2].children[1]
