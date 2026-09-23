"""
Finish Bonito 5.2's static export before deployment.

The writer emits site-relative links, including assets serialized in its
sessions. A per-page base URL fixes nested pages; fragment links, outline
lookup, and the version switcher must be adjusted with it. The checks below
also cover API anchors and search entries, which file-existence checks miss.
"""
function finish_static_export(
    build_dir=joinpath(@__DIR__, "build");
    version=get(ENV, "GITHUB_REF_TYPE", "") == "tag" ? get(ENV, "GITHUB_REF_NAME", "dev") : "dev",
)
    pages = _pb_export_pages()
    scripts = [
        joinpath(root, file)
        for (root, _, files) in walkdir(joinpath(build_dir, "bonito")) for file in files
        if occursin(r"^docs\d+\.js$", file)
    ]
    length(scripts) == 1 || error("Expected one Bonito documentation theme script")
    script = only(scripts)
    javascript = read(script, String)
    old_lookup = "a.getAttribute(\"href\").slice(1)"
    old_versions = "return '<a href=\"../' + v + '/\">' + esc(v) + \"</a>\";"
    for expected in (old_lookup, old_versions)
        count(expected, javascript) == 1 || error(
            "Bonito's navigation code changed; review the static-export adaptation",
        )
    end
    new_versions = "return '<a href=\"' + new URL(v + '/', window.__PB_VERSIONS_ROOT__).href + '\">' + esc(v) + \"</a>\";"
    # Copied package assets can be read-only; create our own patched asset.
    mkpath(joinpath(build_dir, "assets"))
    write(joinpath(build_dir, "assets", "docs-navigation.js"), replace(
        javascript, old_lookup => "a.hash.slice(1)", old_versions => new_versions,
    ))
    original_script_url = _pb_urlpath(relpath(script, build_dir))
    marker = "<meta name=\"pb-static-export\" content=\"1\">"
    canonical_root = "https://vezy.github.io/PlantBiophysics.jl/" * strip(version, '/') * "/"

    for page in pages
        path = joinpath(build_dir, page)
        isfile(path) || error("Missing exported documentation page: $page")
        html = read(path, String)
        if !occursin(marker, html)
            occursin("<base ", html) && error(
                "Bonito now emits a base URL; review the static-export adaptation",
            )
            base = _pb_urlpath(relpath(build_dir, dirname(path))) * "/"
            html = replace(html, original_script_url => "assets/docs-navigation.js")
            # The visible search label is hidden on narrow screens.
            html = replace(html, "data-open-search=\"true\"" =>
                "data-open-search=\"true\" aria-label=\"Search documentation\"")
            html = replace(html, "href=\"#" => "href=\"$page#")
            html = _pb_normalize_links(html, path, build_dir)
            # Version metadata is above dev/stable, but two levels above previews/PRn.
            version_loader = raw"""<script>
            window.__PB_VERSIONS_ROOT__ = new URL(
                /\/previews\/PR\d+\/$/.test(new URL(document.baseURI).pathname) ? '../../' : '../',
                document.baseURI
            ).href;
            if (new URL(document.baseURI).pathname !== '/') {
                document.write('<script src="' + window.__PB_VERSIONS_ROOT__ + 'versions.js"><\/script>');
            }
            </script>"""
            versions_tag = r"<script\b[^>]*\bsrc=\"\.\./versions\.js\"[^>]*></script>"
            count(versions_tag, html) == 1 || error("Expected version metadata script in $page")
            html = replace(html, versions_tag => version_loader)
            extras = "<base href=\"$base\">" * marker *
                "<link rel=\"icon\" type=\"image/png\" href=\"assets/logo.png\">" *
                "<link rel=\"canonical\" href=\"$(canonical_root * page)\">"
            count("<head>", html) == 1 || error("Expected one HTML head in $page")
            html = replace(html, "<head>" => "<head>" * extras; count=1)
            html = replace(html, "</body>" =>
                "<link rel=\"stylesheet\" href=\"assets/brand.css\"></body>"; count=1)
            write(path, html)
        end
        _pb_write_redirect(build_dir, page, canonical_root)
    end
    return check_static_export(build_dir; pages)
end

_pb_urlpath(path) = replace(path, '\\' => '/')

function _pb_export_pages()
    source = joinpath(@__DIR__, "src")
    return sort!([
        replace(_pb_urlpath(relpath(joinpath(root, file), source)), r"\.md$" => ".html")
        for (root, _, files) in walkdir(source) for file in files if endswith(file, ".md")
    ])
end

function _pb_unescape(text)
    decoded = replace(text, "&quot;" => "\"", "&apos;" => "'", "&lt;" => "<", "&gt;" => ">", "&amp;" => "&")
    return replace(decoded, r"&#(?:x[0-9a-fA-F]+|[0-9]+);" => entity -> begin
        digits = entity[3:end-1]
        value = startswith(digits, "x") ? parse(Int, digits[2:end]; base=16) : parse(Int, digits)
        string(Char(value))
    end)
end

function _pb_normalize_links(html, page_path, build_dir)
    # Raw image embeds and some contents links remain page-relative.
    return replace(html, r"(?:href|src)=\"[^\"]*\"" => matched -> begin
        attribute, reference = split(matched, "=\""; limit=2)
        reference = chop(reference; tail=1)
        occursin(r"^(?:[A-Za-z][A-Za-z0-9+.-]*:|/|#)", reference) && return matched
        target = first(split(first(split(reference, '#')), '?'))
        isempty(target) && return matched
        decoded = Bonito.URIs.unescapeuri(_pb_unescape(target))
        ispath(joinpath(build_dir, decoded)) && return matched
        resolved = normpath(joinpath(dirname(page_path), decoded))
        isfile(resolved) || return matched
        relative = _pb_urlpath(relpath(resolved, build_dir))
        suffix = reference[nextind(reference, lastindex(target)):end]
        "$attribute=\"$relative$suffix\""
    end)
end

function _pb_write_redirect(build_dir, page, canonical_root)
    page == "index.html" && return nothing
    # Documenter.HTML used directory URLs on CI. Retain their query and fragment.
    path = joinpath(build_dir, splitext(page)[1], "index.html")
    target = "../" * basename(page)
    mkpath(dirname(path))
    script_target = Bonito.JSON.json(target)
    write(path, """<!doctype html><html><head><meta charset="utf-8">
    <link rel="canonical" href="$(canonical_root * page)">
    <script>window.location.replace($script_target + window.location.search + window.location.hash);</script>
    <noscript><meta http-equiv="refresh" content="0; url=$target"></noscript>
    <title>Documentation moved</title></head><body><a href="$target">Continue to the documentation</a></body></html>
    """)
    return nothing
end

function check_static_export(build_dir=joinpath(@__DIR__, "build"); pages=_pb_export_pages())
    html_pages = Dict(page => read(joinpath(build_dir, page), String) for page in pages)
    anchors = Dict(page => Set(_pb_unescape(m.captures[1]) for m in
        eachmatch(r"\bid=\"([^\"]+)\"", html)) for (page, html) in html_pages)
    binary_files = Set{String}()
    expected_api = BonitoRendering.API_ENTRIES[]
    isempty(expected_api) && error("No API docstrings were indexed during this build")
    rendered_api_count = sum(count(r"<details\b[^>]*\bclass=\"[^\"]*\bjldocstring\b", html)
        for html in values(html_pages))
    rendered_api_count == length(expected_api) || error(
        "Rendered API count ($rendered_api_count) differs from Documenter ($(length(expected_api)))",
    )

    function check_reference(reference, page)
        reference = _pb_unescape(reference)
        occursin(r"^(?:[A-Za-z][A-Za-z0-9+.-]*:|//)", reference) && return
        parts = split(reference, '#'; limit=2)
        target = Bonito.URIs.unescapeuri(first(split(first(parts), '?')))
        isempty(target) && return
        # The base deliberately leads from this page back to the site root.
        base = _pb_urlpath(relpath(build_dir, dirname(joinpath(build_dir, page)))) * "/"
        target == base && return
        ispath(joinpath(build_dir, target)) || error("Missing local target $reference in $page")
        normalized = _pb_urlpath(normpath(target))
        if length(parts) == 2 && !isempty(parts[2]) && haskey(anchors, normalized)
            fragment = Bonito.URIs.unescapeuri(parts[2])
            fragment in anchors[normalized] || error("Missing anchor $reference in $page")
        end
    end

    for page in pages
        html = html_pages[page]
        occursin(r"Bonito\.init_session\([^;]*,\s*false\);"s, html) ||
            error("Missing Bonito static-session bootstrap in $page")
        occursin("<base ", html) || error("Missing site base in $page")
        occursin("rel=\"canonical\"", html) || error("Missing canonical URL in $page")
        # Ignore inline scripts except the explicit session fetch and search index.
        markup = replace(html, r"<script\b[^>]*>.*?</script>"s => matched ->
            first(split(matched, '>'; limit=2)) * ">")
        for matched in eachmatch(r"(?:href|src)=\"([^\"]+)\"", markup)
            check_reference(matched.captures[1], page)
        end
        for matched in eachmatch(r"Bonito\.fetch_binary\([\"']([^\"']+)[\"']\)", html)
            reference = matched.captures[1]
            check_reference(reference, page)
            push!(binary_files, reference)
        end
        search = match(r"window\.__DOCS_SEARCH__\s*=\s*(\[.*?\]);\s*</script>"s, html)
        isnothing(search) && error("Missing search index in $page")
        entries = Bonito.JSON.parse(search.captures[1])
        urls = Set(String(entry["url"]) for entry in entries)
        all(target -> target in urls, pages) || error("Search omits a documentation page in $page")
        all(entry -> entry.url in urls, expected_api) || error("Search omits an API entry in $page")
        for entry in entries
            check_reference(String(entry["url"]), page)
        end
        if page != "index.html"
            redirect = joinpath(build_dir, splitext(page)[1], "index.html")
            isfile(redirect) || error("Missing legacy URL redirect for $page")
            redirect_html = read(redirect, String)
            occursin("window.location.search + window.location.hash", redirect_html) ||
                error("Legacy redirect loses query or fragment for $page")
        end
    end
    isempty(binary_files) && error("Static export contains no Bonito session data")
    @info "Validated static documentation export" pages=length(pages) states=length(binary_files) api_entries=rendered_api_count
    return (pages=length(pages), states=length(binary_files), api_entries=rendered_api_count)
end
