using Test
import MultiDocumenter: DocumenterTools

FIXTURES = joinpath(@__DIR__, "fixtures")

normalize_newlines(s::AbstractString) = replace(s, "\r\n" => "\n")

@testset "walkdocs" begin
    let fileinfos = DocumenterTools.FileInfo[]
        rs = DocumenterTools.walkdocs(joinpath(FIXTURES, "pre")) do fileinfo
            push!(fileinfos, fileinfo)
            @test isabspath(fileinfo.root)
            @test isabspath(fileinfo.fullpath)
            @test !isabspath(fileinfo.relpath)
            @test joinpath(fileinfo.root, fileinfo.relpath) == fileinfo.fullpath
        end
        @test rs === nothing
        @test length(fileinfos) == 9
    end

    let fileinfos = []
        rs = DocumenterTools.walkdocs(
            joinpath(FIXTURES, "pre"),
            DocumenterTools.isdochtml,
        ) do fileinfo
            push!(fileinfos, fileinfo)
            @test isabspath(fileinfo.root)
            @test isabspath(fileinfo.fullpath)
            @test !isabspath(fileinfo.relpath)
            @test joinpath(fileinfo.root, fileinfo.relpath) == fileinfo.fullpath
        end
        @test rs === nothing
        @test length(fileinfos) == 6
    end

    let rs = DocumenterTools.walkdocs(joinpath(FIXTURES, "pre"), collect = true) do fileinfo
            fileinfo.root
        end
        @test length(rs) == 9
        @test all(s -> isa(s, String), rs)
    end
end

function withfiles(f, files::Pair...)
    mktempdir() do path
        for (filename, content) in files
            filepath = joinpath(path, filename)
            if content isa AbstractString
                write(filepath, content)
            elseif content === :dir
                mkdir(filepath)
            elseif content isa Tuple && content[1] === :symlink
                symlink(content[2], filepath)
            else
                error("Invalid content: $content")
            end
        end
        @debug "ls -Alh $path" * read(`ls -Alh $path`, String)
        f(path)
    end
end

@testset "canonical_urls" begin
    @testset "parsing versions.js" begin
        withfiles(
            "versions.js" => """
      var DOC_VERSIONS = [
          "stable",
          "v0.27",
          "v0.1",
          "dev",
      ];
      """,
            "v0.27" => :dir,
            "v0.1" => :dir,
            "dev" => :dir,
            "stable" => (:symlink, "v0.27"),
        ) do path
            @test DocumenterTools.extract_versions_list(joinpath(path, "versions.js")) ==
                  ["stable", "v0.27", "v0.1", "dev"]
            @test DocumenterTools.canonical_version_from_versions_js(path) == "stable"
        end

        withfiles("versions.js" => """
            var DOC_VERSIONS = [
                "v1",
                "v2",
                "dev",
            ];
            """, "v1" => :dir, "v2" => :dir, "dev" => :dir) do path
            @test DocumenterTools.extract_versions_list(joinpath(path, "versions.js")) ==
                  ["v1", "v2", "dev"]
            @test DocumenterTools.canonical_version_from_versions_js(path) == "v2"
        end
    end

    @testset "parsing redirect index.html" begin
        mktempdir() do path
            @test DocumenterTools.canonical_directory_from_redirect_index_html(path) ===
                  nothing
        end

        mktempdir() do path
            file = joinpath(path, "index.html")
            write(
                file,
                """
    <!--This file is automatically generated by Documenter.jl-->
    <meta http-equiv="refresh" content="0; url=./stable/"/>
    """,
            )
            @test DocumenterTools.get_meta_redirect_url(file) == "./stable/"
            @test DocumenterTools.canonical_directory_from_redirect_index_html(path) ==
                  ["stable"]
        end
    end

    @testset "update_canonical_links" begin
        out = tempname()
        cp(joinpath(FIXTURES, "pre"), out)
        @test DocumenterTools.canonical_directory_from_redirect_index_html(out) ==
              ["stable"]
        DocumenterTools.update_canonical_links(
            out;
            canonical = "https://example.org/this-is-test",
        )
        DocumenterTools.walkdocs(joinpath(FIXTURES, "post")) do fileinfo
            post = normalize_newlines(read(fileinfo.fullpath, String))
            changed = normalize_newlines(read(joinpath(out, fileinfo.relpath), String))
            if changed != post
                @error "update_canonical_links: change and post not matching" out fileinfo
            end
            @test changed == post
        end
    end
end
