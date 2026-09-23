# Building the documentation

The documentation has its own Julia environment in `docs/Project.toml`.
It uses the package from this checkout and runs the examples as part of the build.

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
