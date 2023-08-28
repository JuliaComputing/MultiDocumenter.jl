using MultiDocumenter
using Test

@testset "DocumenterTools vendored helpers" begin
    include("documentertools.jl")
end

clonedir = mktempdir()
outpath = joinpath(@__DIR__, "out")
rootpath = "/MultiDocumenter.jl/"
atexit() do
    rm(outpath, recursive = true, force = true)
    rm(clonedir, recursive = true, force = true)
end
docs = [
    MultiDocumenter.DropdownNav(
        "Debugging",
        [
            MultiDocumenter.MultiDocRef(
                upstream = joinpath(clonedir, "Infiltrator"),
                path = "inf",
                name = "Infiltrator",
                giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
            ),
            MultiDocumenter.MultiDocRef(
                upstream = joinpath(clonedir, "JuliaInterpreter"),
                path = "debug",
                name = "JuliaInterpreter",
                giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
            ),
        ],
    ),
    MultiDocumenter.MegaDropdownNav(
        "Mega Debugger",
        [
            MultiDocumenter.Column(
                "Column 1",
                [
                    MultiDocumenter.MultiDocRef(
                        upstream = joinpath(clonedir, "Infiltrator"),
                        path = "inf",
                        name = "Infiltrator",
                        giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
                    ),
                    MultiDocumenter.MultiDocRef(
                        upstream = joinpath(clonedir, "JuliaInterpreter"),
                        path = "debug",
                        name = "JuliaInterpreter",
                        giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
                    ),
                    MultiDocumenter.MultiDocRef(
                        upstream = joinpath(clonedir, "Lux"),
                        path = "lux",
                        name = "Lux",
                        giturl = "https://github.com/avik-pal/Lux.jl",
                    ),
                ],
            ),
            MultiDocumenter.Column(
                "Column 2",
                [
                    MultiDocumenter.MultiDocRef(
                        upstream = joinpath(clonedir, "Infiltrator"),
                        path = "inf",
                        name = "Infiltrator",
                        giturl = "https://github.com/JuliaDebug/Infiltrator.jl.git",
                    ),
                    MultiDocumenter.MultiDocRef(
                        upstream = joinpath(clonedir, "JuliaInterpreter"),
                        path = "debug",
                        name = "JuliaInterpreter",
                        giturl = "https://github.com/JuliaDebug/JuliaInterpreter.jl.git",
                    ),
                ],
            ),
        ],
    ),
    MultiDocumenter.MultiDocRef(
        upstream = joinpath(clonedir, "DataSets"),
        path = "data",
        name = "DataSets",
        giturl = "https://github.com/JuliaComputing/DataSets.jl.git",
        # or use ssh instead for private repos:
        # giturl = "git@github.com:JuliaComputing/DataSets.jl.git",
    ),
]
MultiDocumenter.make(
    outpath,
    docs;
    search_engine = MultiDocumenter.SearchConfig(
        index_versions = ["stable", "dev"],
        engine = MultiDocumenter.FlexSearch,
    ),
    custom_scripts = [
        "foo/bar.js",
        "https://foo.com/bar.js",
        Docs.HTML("const foo = 'bar';"),
    ],
    rootpath = rootpath,
    canonical_domain = "https://example.org/",
    sitemap = true,
    sitemap_filename = "sitemap-mydocs.xml",
)

@testset "MultiDocumenter.jl" begin

    @testset "structure" begin
        @test isdir(outpath, "inf")
        @test !isdir(outpath, "inf", "previews")
        @test isdir(outpath, "inf", "stable")
        @test isfile(outpath, "inf", "stable", "index.html")

        @test read(joinpath(outpath, "inf", "index.html"), String) == """
        <!--This file is automatically generated by Documenter.jl-->
        <meta http-equiv="refresh" content="0; url=./stable/"/>
        """

        # We override the sitemap filename
        @test !isfile(joinpath(outpath, "sitemap.xml"))
        @test isfile(joinpath(outpath, "sitemap-mydocs.xml"))
    end


    @testset "custom scripts" begin
        index = read(joinpath(outpath, "inf", "stable", "index.html"), String)

        @test occursin(
            """<script charset="utf-8" type="text/javascript">window.MULTIDOCUMENTER_ROOT_PATH = '$rootpath'</script>""",
            index,
        )
        @test occursin(
            """<script charset="utf-8" src="../../foo/bar.js" type="text/javascript"></script>""",
            index,
        )
        @test occursin(
            """<script charset="utf-8" src="https://foo.com/bar.js" type="text/javascript"></script>""",
            index,
        )
        @test occursin(
            """<script charset="utf-8" type="text/javascript">const foo = 'bar';</script>""",
            index,
        )
    end

    @testset "canonical URLs" begin
        index = read(joinpath(outpath, "inf", "stable", "index.html"), String)
        canonical_href = "<link href=\"https://example.org/MultiDocumenter.jl/inf/stable/\" rel=\"canonical\"/>"
        @test occursin(canonical_href, index)

        index = read(joinpath(outpath, "inf", "v1.6.0", "index.html"), String)
        canonical_href = "<link href=\"https://example.org/MultiDocumenter.jl/inf/stable/\" rel=\"canonical\"/>"
        @test occursin(canonical_href, index)
    end

    @testset "flexsearch" begin
        @test isdir(outpath, "search-data")
        store_content = read(joinpath(outpath, "search-data", "store.json"), String)
        @test !isempty(store_content)
        @test occursin("Infiltrator.jl", store_content)
        @test occursin("@infiltrate", store_content)
        @test occursin("$(rootpath)inf/stable/", store_content)
        @test occursin("$(rootpath)inf/stable/", store_content)
        @test !occursin("/inf/dev/", store_content)
    end

    @testset "sitemap" begin
        @testset "normalize_canonical_url" begin
            @test MultiDocumenter.normalize_canonical_url("") == ""
            @test MultiDocumenter.normalize_canonical_url("/") == "/"
            @test MultiDocumenter.normalize_canonical_url("//") == "//"
            @test MultiDocumenter.normalize_canonical_url("foo") == "foo"
            @test MultiDocumenter.normalize_canonical_url("foo/") == "foo/"
            @test MultiDocumenter.normalize_canonical_url("foo//") == "foo//"
            @test MultiDocumenter.normalize_canonical_url("foo/bar") == "foo/bar"
            @test MultiDocumenter.normalize_canonical_url("foo/bar/") == "foo/bar/"
            @test MultiDocumenter.normalize_canonical_url("foo/bar//") == "foo/bar//"
            @test MultiDocumenter.normalize_canonical_url("foo//bar") == "foo//bar"
            @test MultiDocumenter.normalize_canonical_url("foo.html") == "foo.html"
            @test MultiDocumenter.normalize_canonical_url("/foo.html") == "/foo.html"
            @test MultiDocumenter.normalize_canonical_url("/foo/bar.html") ==
                  "/foo/bar.html"
            @test MultiDocumenter.normalize_canonical_url("/foo.html/") == "/foo.html/"
            @test MultiDocumenter.normalize_canonical_url("/index.html") == "/"
            @test MultiDocumenter.normalize_canonical_url("/foo/index.html") == "/foo/"
            @test MultiDocumenter.normalize_canonical_url("/foo/index.html") == "/foo/"
            @test MultiDocumenter.normalize_canonical_url("/foo/index.html/") ==
                  "/foo/index.html/"
            @test MultiDocumenter.normalize_canonical_url("/foo/index.html/bar") ==
                  "/foo/index.html/bar"
            @test MultiDocumenter.normalize_canonical_url("/foo/index.html/bar/") ==
                  "/foo/index.html/bar/"
            @test MultiDocumenter.normalize_canonical_url("/foo/index.html/bar/baz.html") ==
                  "/foo/index.html/bar/baz.html"
            @test MultiDocumenter.normalize_canonical_url(
                "/foo/index.html/bar/index.html",
            ) == "/foo/index.html/bar/"
            # Full URL test cases
            @test MultiDocumenter.normalize_canonical_url("https://example.org") ==
                  "https://example.org"
            @test MultiDocumenter.normalize_canonical_url("https://example.org/") ==
                  "https://example.org/"
            @test MultiDocumenter.normalize_canonical_url("https://example.org/foo.html") ==
                  "https://example.org/foo.html"
            @test MultiDocumenter.normalize_canonical_url(
                "https://example.org/index.html",
            ) == "https://example.org/"
            @test MultiDocumenter.normalize_canonical_url("https://example.org/foo") ==
                  "https://example.org/foo"
            @test MultiDocumenter.normalize_canonical_url("https://example.org/foo/") ==
                  "https://example.org/foo/"
            @test MultiDocumenter.normalize_canonical_url(
                "https://example.org/foo/index.html",
            ) == "https://example.org/foo/"
            @test MultiDocumenter.normalize_canonical_url(
                "https://example.org/foo/bar.html",
            ) == "https://example.org/foo/bar.html"
            # Edge case that should maybe be "/", but not worth having a special case for
            @test MultiDocumenter.normalize_canonical_url("index.html") == "index.html"
        end

        sitemap_content = read(joinpath(outpath, "sitemap-mydocs.xml"), String)
        @test occursin(
            "https://example.org/MultiDocumenter.jl/inf/stable/",
            sitemap_content,
        )
        @test occursin(
            "https://example.org/MultiDocumenter.jl/debug/stable/",
            sitemap_content,
        )
        @test occursin(
            "https://example.org/MultiDocumenter.jl/inf/stable/API/",
            sitemap_content,
        )
        @test !occursin(
            "https://example.org/MultiDocumenter.jl/inf/v1/API/",
            sitemap_content,
        )
        @test !occursin(
            "https://example.org/MultiDocumenter.jl/inf/v1.6/API/",
            sitemap_content,
        )
        @test !occursin(
            "https://example.org/MultiDocumenter.jl/inf/v1.6.0/API/",
            sitemap_content,
        )
    end

end
