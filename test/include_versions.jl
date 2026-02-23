using Test
using MultiDocumenter

@testset "include_versions" begin
    @testset "giturl_to_ghpages_url" begin
        @test MultiDocumenter.giturl_to_ghpages_url("https://github.com/NREL-Sienna/PowerSystems.jl.git") ==
            "https://nrel-sienna.github.io/PowerSystems.jl/"
        @test MultiDocumenter.giturl_to_ghpages_url("https://github.com/JuliaDebug/Infiltrator.jl.git") ==
            "https://juliadebug.github.io/Infiltrator.jl/"
        @test MultiDocumenter.giturl_to_ghpages_url("https://github.com/avik-pal/Lux.jl") ==
            "https://avik-pal.github.io/Lux.jl/"
        @test isempty(MultiDocumenter.giturl_to_ghpages_url(""))
        @test isempty(MultiDocumenter.giturl_to_ghpages_url("https://gitlab.com/org/repo"))
    end

    @testset "cp_select_versions" begin
        mktempdir() do src
            write(joinpath(src, "index.html"), "<!DOCTYPE html>")
            write(joinpath(src, "versions.js"), "var DOC_VERSIONS = [];")
            mkdir(joinpath(src, "stable"))
            write(joinpath(src, "stable", "index.html"), "stable")
            mkdir(joinpath(src, "dev"))
            write(joinpath(src, "dev", "index.html"), "dev")
            mkdir(joinpath(src, "v1.0"))
            write(joinpath(src, "v1.0", "index.html"), "v1.0")

            mktempdir() do dst
                MultiDocumenter.cp_select_versions(src, dst, ["stable", "dev"])

                @test isfile(joinpath(dst, "index.html"))
                @test isfile(joinpath(dst, "versions.js"))
                @test isdir(joinpath(dst, "stable"))
                @test read(joinpath(dst, "stable", "index.html"), String) == "stable"
                @test isdir(joinpath(dst, "dev"))
                @test read(joinpath(dst, "dev", "index.html"), String) == "dev"
                @test !isdir(joinpath(dst, "v1.0"))
                @test !isdir(joinpath(dst, ".git"))
            end
        end
    end

    @testset "cp_select_versions with symlink stable" begin
        Sys.iswindows() && @test_broken "symlinks not reliably testable on Windows"
        Sys.iswindows() && return
        mktempdir() do src
            write(joinpath(src, "versions.js"), "var DOC_VERSIONS = [];")
            mkdir(joinpath(src, "v5.5.0"))
            write(joinpath(src, "v5.5.0", "siteinfo.js"), "{}")
            # stable -> v5.5.0 (simulates Documenter deploy)
            symlink("v5.5.0", joinpath(src, "stable"))
            mkdir(joinpath(src, "dev"))
            write(joinpath(src, "dev", "siteinfo.js"), "{}")

            mktempdir() do dst
                MultiDocumenter.cp_select_versions(src, dst, ["stable", "dev"])

                @test isfile(joinpath(dst, "versions.js"))
                @test isdir(joinpath(dst, "stable"))
                @test isfile(joinpath(dst, "stable", "siteinfo.js"))
                @test isdir(joinpath(dst, "dev"))
                @test !isdir(joinpath(dst, "v5.5.0"))
            end
        end
    end

    @testset "rewrite_versions_js" begin
        mktempdir() do dir
            vjs = joinpath(dir, "versions.js")
            write(vjs, """
            var DOC_VERSIONS = [
                "stable",
                "v1.0",
                "dev",
            ];
            """)
            MultiDocumenter.rewrite_versions_js(dir, ["stable", "dev"])
            content = read(vjs, String)
            @test occursin("DOC_VERSIONS", content)
            @test occursin("\"stable\"", content)
            @test occursin("\"dev\"", content)
            @test !occursin("v1.0", content)
        end
    end

    @testset "inject_all_versions_link" begin
        mktempdir() do dir
            html = joinpath(dir, "page.html")
            write(html, """
            <!DOCTYPE html>
            <html><head></head><body>
            <div class="docs-version-selector"><select><option>stable</option></select></div>
            </body></html>
            """)
            url = "https://example.org/pkg.jl/"
            MultiDocumenter.inject_all_versions_link(html, url)
            content = read(html, String)
            @test occursin("documenter-see-all-versions-option", content)
            @test occursin("See All Versions", content)
            @test occursin(url, content)
            @test occursin("</body>", content)
        end
    end

    @testset "inject_all_versions_link idempotent" begin
        mktempdir() do dir
            html = joinpath(dir, "page.html")
            write(html, """<html><body><div class="docs-version-selector"><select><option>stable</option></select></div></body></html>""")
            MultiDocumenter.inject_all_versions_link(html, "https://x.org/")
            first_run = read(html, String)
            MultiDocumenter.inject_all_versions_link(html, "https://x.org/")
            second_run = read(html, String)
            @test first_run == second_run
            @test count("documenter-see-all-versions-option", first_run) == 1
        end
    end

    @testset "MultiDocRef include_versions and all_versions_url" begin
        ref = MultiDocumenter.MultiDocRef(
            upstream = "/tmp/up",
            path = "pkg",
            name = "Pkg",
            giturl = "https://github.com/org/Pkg.jl.git",
            include_versions = ["stable", "dev"],
            all_versions_url = "https://custom.github.io/Pkg.jl/",
        )
        @test ref.include_versions == ["stable", "dev"]
        @test ref.all_versions_url == "https://custom.github.io/Pkg.jl/"

        ref2 = MultiDocumenter.MultiDocRef(
            upstream = "/tmp/up",
            path = "pkg",
            name = "Pkg",
            giturl = "https://github.com/org/Pkg.jl.git",
        )
        @test ref2.include_versions === nothing
        @test ref2.all_versions_url === nothing
    end
end
