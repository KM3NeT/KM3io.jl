using Documenter, KM3io

makedocs(;
    modules = [KM3io],
    sitename = "KM3io.jl",
    authors = "Tamas Gal",
    format = Documenter.HTML(;
        assets = ["assets/extra_styles.js"],
        collapselevel = 1,
        warn_outdated = true,
    ),
    pages = [
        "Home" => "index.md",
        "Examples" => Any[
            "Offline data" => "examples/offline_data.md",
            "Cherenkov times" => "examples/cherenkov_times.md",
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
