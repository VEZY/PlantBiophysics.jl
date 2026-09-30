# Building the documentation

The documentation uses Bonito's Documenter writer for its landing page, theme,
navigation, and search. It has its own Julia environment in `docs/Project.toml`
and requires Julia 1.11 or later (CI uses Julia 1.12).
It uses the package from this checkout and runs the examples as part of the build.

The build checks exported pages, figures, local links, API anchors, and search
entries before deployment. It keeps redirects for the previous directory URLs
and an `objects.inv` inventory for links from other documentation sites.
Bonito is bounded to the 5.2 series because the navigation helper adapts that
theme's export; review the helper when upgrading Bonito.

To build locally without deployment, start a Julia session with the `docs`
environment, instantiate it, and run:

```julia
ENV["PLANTBIOPHYSICS_DOCS_BUILD_ONLY"] = "true"
include("make.jl") # from the docs directory
```

Serve `docs/build` with a local HTTP server to preview the site. For example,
from the repository root:

```sh
python3 -m http.server 8767 --bind 127.0.0.1 --directory docs/build
```

The documentation workflow builds pull requests and publishes previews when
deployment credentials are available. The main documentation is deployed from
`master` and release tags.
