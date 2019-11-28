using Documenter, KM3io

makedocs(;
    modules=[KM3io],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://git.km3net.de/jschumann/KM3io.jl/blob/{commit}{path}#L{line}",
    sitename="KM3io.jl",
    authors="Johannes Schumann, Tamas Gal",
    assets=String[],
)
