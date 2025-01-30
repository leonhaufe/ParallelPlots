using Random: seed!, rand
using DataFrames: DataFrame
using CairoMakie: LineSegments, Lines


#generate Data
function create_person_df(n_samples = 10)

    seed!(10)
    df = DataFrame(
        height=rand(150:180, n_samples),
        weight=rand(40:130, n_samples),
        income=rand(450:5000, n_samples),
        education_years=rand(0:25, n_samples), # random numbers between 0 and 70
        age=rand(0:70, n_samples), # random numbers between 0 and 70

    )

    return df
end

function create_log_df(log = 10)
    df = DataFrame(height=[log^1,log^2,log^3],weight=[log^3,log^2,log^1],age=[log^3,log^2,log^1],income=[log^1,log^2,log^3])
    return df
end

function create_car_df(n_samples = 10)

    seed!(10)
    df = DataFrame(
        horsepower=rand(60:300, n_samples),
        weight=rand(90:2000, n_samples),
        age=rand(0:70, n_samples)
    )

    return df
end
#count line segments in a plot
function count_line_segments(fig)
    return length(filter(
        x->(typeof(x)<:LineSegments),
        fig.scene.plots))
end

#counts lines except black ones
function count_lines(fig) 
    return length(filter(
        x-> typeof(x)<:Lines && !(x[:color][] == :black),
        fig.scene.plots))
end