using ParallelPlots: parallelplot
using Test:@test, @testset
using CairoMakie: save

@testset "call with scene width & height" begin

    # Generate sample multivariate data
    df = create_person_df()

    #display
    fig = parallelplot(df, figure = (size = (300, 300),))

    @test fig !== nothing

    save("parallel_coordinates_plot_300x300.png", fig)

end
