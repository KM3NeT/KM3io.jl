using Documenter, KM3io

makedocs(;
    modules=[KM3io],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "API" => "api.md"
    ],
    repo="https://git.km3net.de/common/KM3io.jl/blob/{commit}{path}#L{line}",
    sitename="KM3io.jl",
    authors="Tamas Gal",
    assets=String[],
)
