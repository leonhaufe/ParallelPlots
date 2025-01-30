using ParallelPlots:parallelplot
using Test: @test, @testset
using CairoMakie: save

@testset "default call log scaled" begin


    # create log2 data for easy visual check
    df = create_log_df(2)
    fig = parallelplot(df, curve=true,
        feature_selection=["height","age","income"],
        scale=[log2, identity, log2]
    )
    @test fig !== nothing
    save("parallel_coordinates_plot_logScaled_2.png", fig)

    # create log10 data for easy visual check
    df = create_log_df(10)
    fig = parallelplot(df,
        scale=[log10, identity, log10],
        feature_selection=["height","age","income"],
    )
    @test fig !== nothing
    save("parallel_coordinates_plot_log_10.png", fig)

    #  length of scale attributes does not fit the length of the axis/features
    @test_throws AssertionError begin
        fig = parallelplot(df,
            scale=[log10, identity, log10],
            feature_selection=["height","weight","age","income"],
        )
    end

    #  length of scale attributes does not fit the length of the axis/features
    @test_throws ArgumentError begin
        fig = parallelplot(df,
            scale=[log10, identity, log10, sqrt],
            feature_selection=["height","weight","age","income"],
        )
    end

end
