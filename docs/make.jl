using Documenter, KM3io

makedocs(;
    modules = [KM3io],
    sitename = "KM3io.jl",
    authors = "Tamas Gal",
    format = Documenter.HTML(;
        assets = ["assets/custom.css"],
        sidebar_sitename = false,
        collapselevel = 4,
        warn_outdated = true,
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "manual/rootfiles.md",
        ],
        "Examples" => Any[
            "examples/offline_data.md",
            "examples/cherenkov_times.md",
            "examples/controlhost.md",
        ],
        "API" => "api.md"
    ],
    repo = "https://git.km3net.de/common/KM3io.jl/blob/{commit}{path}#L{line}",
)

deploydocs(;
  repo = "git.km3net.de/common/KM3io.jl",
  devbranch = "main",
  push_preview=true
)
