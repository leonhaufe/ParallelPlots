using ParallelPlots
using Documenter
using DataFrames

DocMeta.setdocmeta!(ParallelPlots, :DocTestSetup, :(using ParallelPlots); recursive=true)

makedocs(;
    modules=[ParallelPlots],
    authors="Moritz Schelten <moritz155@win.tu-berlin.de>, Leon Haufe <leon.haufe@campus.tu-berlin.de>",
    sitename="ParallelPlots",
    format=Documenter.HTML(;
        canonical="https://leonhaufe.github.io/ParallelPlots",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting started" => "getting_started.md",
        "Functions" => "functions.md",
    ],
)

deploydocs(;
    repo="github.com/leonhaufe/ParallelPlots",
    devbranch="main",
)
