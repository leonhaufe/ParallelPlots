module ParallelPlots

using CairoMakie: Makie, Axis, Colorbar, Point2f, Point2, text!, lines!, empty!, current_figure, hidespines!, size, Observable, lift, @recipe, Attributes, hidedecorations!, on
using DataFrames: DataFrame, names, eachcol, size, minimum, maximum


"""

	input_data_check(data::DataFrame)

checks the Input Data if the size is correct and no missing values are available

### Input:
- DataFrame
### Output:
- none
### Trows
Throws error on wrong DF
"""
function input_data_check(data::DataFrame)::Nothing
	if size(data, 2) < 2 # otherwise there will be a nullpointer exception later
		throw(ArgumentError("Data must have at least two columns, currently ("*string(size(data, 2))*")"))
	end
	if size(data, 1) < 2 # otherwise there will be a nullpointer exception later
		throw(ArgumentError("Data must have at least two lines, currently ("*string(size(data, 1))*") Rows"))
	end
	if any(collect(any(ismissing.(c)) for c in eachcol(data))) # checks for missing values
		throw(ArgumentError("Data cannot have missing values"))
	end
end



"""

	parallelplot(data::DataFrame, _Arguments_)


# Arguments

| Parameter         | Default  | Example                            | Description                                                                                                                |
|-------------------|----------|------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| title::String     | ""       | title="My Title"                   | The Title of The Figure,                                                                                                   |
| colormap          | :viridis | colormap=:thermal                  | The Colors of the [Lines](https://docs.makie.org/dev/explanations/colors)                                                  |
| color_feature     | nothing  | color_feature="weight"             | The Color of the Lines will be based on the values of this selected feature. If nothing, the last feature will be used     |
| feature_labels    | nothing  | feature_labels=["Weight","Age"]    | Add your own Axis labels, just use the exact amount of labes as you have axis                                              |
| feature_selection | nothing  | feature_selection=["weight","age"] | Select, which features should be Displayed. If color_feature is not in this List, use the last one                         |
| curve             | false    | curve=true                         | Show the Lines Curved                                                                                                      |
| show_color_legend | nothing  | show_color_legend=true             | Show the Color Legend. If parameter not set & color_feature not shown, it will be displayed automaticly                    |
| scale             | nothing  | scale=[log2, identity, log10]      | Choose, how each Axis should be scaled. In the Example. The first Axis will be log2, the second linear and the third log10 |


# Examples
```jldoctest
julia> using DataFrames

julia> fig, ax, sc = parallelplot(DataFrame(height=160:180,weight=60:80,age=20:40))
FigureAxisPlot()

julia> display(fig)
CairoMakie.Screen{IMAGE}
```
Using DrWatson with ParallelPlot
```jldoctest
julia> using DataFrames, DrWatson, ParallelPlots

julia> function exec_simulation(d::Dict, results)
           @unpack launch_angles, initial_velocities = d
           max_height = initial_velocities * launch_angles
           push!(results, [
               initial_velocities,
               launch_angles,
               max_height,
           ])
           return results
       end;

julia> initial_velocities = [40.0, 50.0];

julia> launch_angles = [30.0, 60.0];

julia> allparams = Dict(
           "initial_velocities" => initial_velocities,
           "launch_angles" => launch_angles,
       );

julia> dicts = dict_list(allparams);

julia> results = DataFrame(
           initial_velocity=Float64[],
           launch_angle=Float64[],
           max_height=Float64[],
       );

julia> for d in dicts
           results = exec_simulation(d, results)
       end;

julia> fig = parallelplot(results, curve=true, figure = (size = (1000, 600),));

julia> display(fig);
```
```@example
# If you want to set the size of the plot
julia> parallelplot( DataFrame(height=160:180,weight=60:80,age=20:40), figure = (resolution = (300, 300),) )
```
```
# You can update the Graph with Observables as well 
julia> df_observable = Observable(DataFrame(height=160:180,weight=60:80,age=20:40))
julia> fig, ax, sc = parallelplot(df_observable)
```
```
# If you want to add a Title for the Figure, sure you can!
julia> parallelplot(DataFrame(height=160:180,weight=reverse(60:80),age=20:40),title="My Title")
```
```
# If you want to specify the axis labels, make sure to use the same number of labels as you have axis!
julia> parallelplot(DataFrame(height=160:180,weight=reverse(60:80),age=20:40), feature_labels=["Height","Weight","Age"])
```
```
# Adjust Color and and Feature
parallelplot(df,
		# You choose which axis/feature should be in charge for the coloring
        color_feature="weight",
        # you can as well select, which Axis should be shown
        feature_selection=["height","age","income"],
        # and label them as you like
        feature_labels=["Height","Age","Income"],
        # you can change the ColorMap (https://docs.makie.org/dev/explanations/colors)
        colormap=:thermal,
        # ...and can choose to display the color legend.
        # If this Attribute is not set,
        # it will only show the ColorBar, when the color feature is not in the selected feature
        show_color_legend = true
    )
```
```
# Adjust the Axis scale
parallelplot(df,
        feature_selection=["height","age","income"],
        scale=[log2, identity, log10]
    )
```

"""
@recipe(ParallelPlot, df) do scene
	Attributes(
		# additional attributes
		title = "", # Title of the Figure
		colormap = :viridis,  # https://docs.makie.org/dev/explanations/colors
		color_feature = nothing,    # Which feature to use for coloring (column name)
		feature_labels = nothing, # the Label of each feature as List of Strings
		feature_selection = nothing, # which features should be shown, default: nothing --> show all features
		curve = false, # If Lines should be curved between the axis. Default false
		# if colorlegend/ ColorBar should be shown. Default: when color_feature is not visible, true, else false
		show_color_legend = nothing,
		scale = nothing
	)
end


function Makie.plot!(pp::ParallelPlot)

	# this helper function will update our observables
	# whenever df_observable change
	function update_plot(data)

		if isnothing(data)
			throw(ArgumentError("Data cannot be nothing"))
		end

		# check the given DataFrame
		input_data_check(data)

		# Get the Fig and empty it, so its nice and clean for the next itaration
		fig = current_figure()
		empty!(fig)
		scene = fig.scene

		# Create Overlaying, invisible Axis
		# set hight to fit Label
		ax = Axis(fig[1, 1],
			title = pp.title
		)

		# set the Color of the Color Feature
		color_col, color_values, color_min, color_max = calculate_color(pp, data)

		# Select the Columns, the user wants to show (feature_selection)
		if !isnothing(pp.feature_selection[])
			# check if all given selections are in the DF
			for selection in pp.feature_selection[]
				@assert selection in names(data) "Feature Selection ("*selection*") is not available in DataFrame ("*string(names(data))*")"
			end
			data = data[:, pp.feature_selection[]]
		end

		# set the axis labels, if available
		# check if ax_label has the same amount of labels as axis
		labels = if isnothing(pp.feature_labels[])  # check if ax_label is set
			names(data) # ax_label is not set, use the DB label
		else
			@assert length(pp.feature_labels[]) === length(names(data)) "'feature_labels' is set but has not the same amount of labels("*string(length(pp.feature_labels[]))*") as axis("*string(length(names(data)))*")"
			pp.feature_labels[]
		end


		# COLOR FEATURE
		# If set, use the setted value
		# Show, when color_feature is not in feature_selection
		show_color_legend = show_color_legend!(pp)

		# set the Color Bar on the side if it should be set
		if show_color_legend[]
			Colorbar(
				fig[1, 2],
				limits = (color_min, color_max),
				colormap = pp.colormap[],
				label = color_col,
			)
		end

		# get the parent scene dimensions
		scene_width, scene_height = size(ax.scene)

		# Plot dimensions
		width = scene_width[] * 0.95  #% of scene width
		height = scene_height[] * 0.95  #% of scene width
		offset = min(scene_width[], scene_height[]) * 0.1  #% of scene dimensions

		# make the Axis invisible
		hidespines!(ax)
		hidedecorations!(ax)

		# Parse the DataFrame into a list of arrays
		parsed_data = [data[!, col] for col in names(data)]

		# Compute limits for each column
		limits = [(minimum(col), maximum(col)) for col in parsed_data]

		numberFeatures = length(parsed_data) # Number of features, equivalent to the X Axis
		sampleSize = size(data, 1)       # Number of samples, equivalent to the Y Axis

		#create the list of scales for each Axis/feature
		scale_list = create_scale_list(numberFeatures, pp.scale[])

		# # # # # # # # # #
		# # # L I N E # # #
		# # # # # # # # # #

		# Draw lines connecting points for each row
		draw_lines(
			scene,
			pp,
			data,
			width,
			height,
			offset,
			limits,
			numberFeatures,
			scale_list,
			sampleSize,
			parsed_data,
			color_values,
			color_min,
			color_max
		)

		# # # # # # # # # #
		# # # A X I S # # #
		# # # # # # # # # #


		# Create the new Parallel Axis
		draw_axis(
			scene,
			width,
			height,
			offset,
			limits,
			labels,
			numberFeatures,
			scale_list
		)


    end

	# our first parameter is the DataFrame-Observable
	df_observable = pp[1]

	# add listener to Observable Arguments and trigger an update on change
	# loop thorough the given Arguments
	for kw in pp.kw
		# e.g. curve
		attribute_key = kw[1]
		on(pp[attribute_key]) do x
			# trigger update
			notify(df_observable)
		end
	end

	# connect `update_plot` so that it is called whenever the DataFrame changes
	Makie.Observables.onany(update_plot, df_observable)

	# then call it once manually with the first dataFrame
	# contents so we prepopulate all observables with correct values
	update_plot(df_observable[])

	# lastly we return the new ParallelPlot
	pp
end

"""

	create_scale_list(numberFeatures :: Number, scale_list)

check the length of the given scale Attribute. Throws an Error if the Length does not match the amount of axis/features
If scale is not set, identity, so linear will be used for all axis.
if the length of the scale attribute does not fit, an assert error will be thrown

### Input:
- numberFeatures::Number
- scale_list 	nothing or Vector e.g. [log2, log10, identity]
### Output:
- given scale_list or vector of [identity, identity, ...] with the length of axis/features
### Throws
Assertion, if amount of scales in the scale list does not match the amount of axis/features
"""
function create_scale_list(numberFeatures :: Number, scale_list)
    if isnothing(scale_list)
    	[identity for i = 1:numberFeatures]
	else
		@assert length(scale_list) === numberFeatures "The Number of given scales ("*string(length(scale_list))*") does not match the amount of axis/features ("*string(numberFeatures)*")"
		return scale_list
	end
end

"""

	get_color_col(pp::ParallelPlot, data::DataFrame) :: AbstractString

get the name of the Column, on which the Color should be dependent

### Input:
- pp::ParallelPlot
- data::DataFrame
### Output:
- AbstractString
"""
function get_color_col(pp::ParallelPlot, data::DataFrame) :: AbstractString
	color_col = if isnothing(pp.color_feature[])  # check if colorFeature is set
			# Its not Set, use the last feature
			# therefore we need to check if user selected features
			if !isnothing(pp.feature_selection[])
				# use the last seleted feature as color_col
				@assert pp.feature_selection[][end] in names(data) "Feature Selection ("*repr(pp.feature_selection[][end])*") is not available in DataFrame ("*string(names(data))*")"
				pp.feature_selection[][end]
			else
				names(data)[end] # no columns selected, use the last one
			end

		else
			# check if name is available
			@assert pp.color_feature[] in names(data) "Color Feature ("*repr(pp.color_feature[])*") is not available in DataFrame ("*string(names(data))*")"
			pp.color_feature[]
		end
	return color_col
end

"""

	calculate_color(pp::ParallelPlot, data::DataFrame) :: Tuple{AbstractString, Vector{Real}, Real, Real}

Calculates the Color values for the Lines

### Input:
- pp::ParallelPlot
- data::DataFrame
### Output:
- color_col  	result of `get_color_col`
- color_values 	The List of Values of the `color_col`. Needed to calculate the Color for each Line
- color_min 	The min value of `color_values`. To Calculate the ColorRange
- color_max 	The max value of `color_values`. To Calculate the ColorRange
"""
function calculate_color(pp::ParallelPlot, data::DataFrame) :: Tuple{AbstractString, Vector{Real}, Real, Real}
	color_col:: AbstractString = get_color_col(pp, data)
    color_values::Vector{Real} = data[:,color_col]  # Get all values for selected feature
    color_min::Real = minimum(color_values)
    color_max::Real = maximum(color_values)

	return color_col, color_values, color_min, color_max

end

"""

	show_color_legend!(pp) :: Bool

Returns Boolean if the Color Legend/Bar on the right should be shown

### Input:
- pp::ParallelPlot
### Output:
- boolean if `show_color_legend` from the Arguments is set, return this value. Else show, when color_feature is not in feature_selection
"""
function show_color_legend!(pp) :: Bool
	if pp.show_color_legend[] == true
		return true
	elseif pp.show_color_legend[] == false
		return false
	elseif isnothing(pp.color_feature[])
		return false
	elseif !isnothing(pp.feature_selection[]) && !(pp.color_feature[] in pp.feature_selection[])
		return true
	else
		return false
	end
end


"""

	draw_lines(
		scene,
		pp,
		data,
		width::Number,
		height::Number,
		offset::Number,
		limits,
		numberFeatures::Number,
		scale_list,
		sampleSize::Number,
		parsed_data,
		color_values,
		color_min,
		color_max
	)

Function to Draw the Lines connecting the Values on each Axis into the Plot


"""
function draw_lines(
    scene,
	pp,
	data,
	width::Number,
	height::Number,
	offset::Number,
	limits,
	numberFeatures::Number,
	scale_list,
	sampleSize::Number,
	parsed_data,
	color_values,
	color_min,
	color_max
	)
	for i in 1:sampleSize
		dataPoints = Vector{Point2f}(undef, numberFeatures)
		# If Curved, Interpolate
		if(pp.curve[] == false)
    		# calcuating the point respectivly of the width and height in the Screen
    		dataPoints = [
				Point2f(
					# calculates which feature the Point should be on
					offset + (j - 1) / (numberFeatures - 1) * width,
					# calculates the Y axis value
					calc_y_coordinate(parsed_data, limits, height,offset, j, i, scale_list),
				)
				# iterates through the Features/Axis and creates for each feature the samplePoint (above)
				for j in 1:numberFeatures
			]
		else
			# Interpolate
			dataPoints = []

			# iterates through the Features/Axis
			# Start at 2, bc we check the precious axis/feature f
			for j in 2:numberFeatures
				last_x = offset + ((j-1) - 1) / (numberFeatures - 1) * width
				current_x = offset + ((j) - 1) / (numberFeatures - 1) * width
				last_y = calc_y_coordinate(parsed_data, limits, height, offset, j-1, i, scale_list)
				current_y = calc_y_coordinate(parsed_data, limits, height,offset, j, i, scale_list)
				# interpolate points between the current and the last point
				for x in range(last_x, current_x, step = ( (current_x-last_x) / 30 ) )
					# calculate the interpolated Y Value
					y = interpolate(last_x, current_x, last_y, current_y, x)
					# create a new Point
					push!(dataPoints, Point2f(x,y))
				end
			end

		end

		# Create the Line
        lines!(scene, dataPoints,
        	color = color_values[i],
            colormap = pp.colormap[],
            colorrange = (color_min, color_max)
        )
	end
end

"""
    calc_y_coordinate(parsed_data, limits, height, offset, feature_index :: Number, sample_index :: Number, scale_list) :: Number

This function will return the y position in the scene, depending of the scale if set

### Output:
- the y position of the datapoint in the scene
"""
function calc_y_coordinate(parsed_data, limits, height, offset, feature_index :: Number, sample_index :: Number, scale_list) :: Number

	# linear factor between 0 and 1, depending on the value inside the feature
	factor = (
				(parsed_data[feature_index][sample_index] - limits[feature_index][1])
				/
				(limits[feature_index][2] - limits[feature_index][1])
			)

	# get the scale of the current feature
	scale = scale_list[feature_index]

	# change the linear factor - when needed - with the equivalent function for a log distribution
	# throws error when cscalijg parameter is not one of [identity, log2, log10]
	if scale === identity
	elseif scale === log2
		factor = log_scale2(factor)
	elseif scale === log10
		factor = log_scale10(factor)
	else
		throw(ArgumentError("The scaling parameter '"*string(scale)*"' is currently not supported. Supported: [identity, log2, log10]"))
	end

	# return the y position. use the height depending on the factor (full/no height)
	return factor * height + offset
end

"""
    log_scale10(x::Float64)

In Linear Axis represenatation, values between 0-1 are linear distributed.
Due to the Logarithmfunction, we need to distribute the values with the given log values to match the axis

### Input:
- value x, distributed between 0 and 1
### Output:
- the log10 distribution, beween 0 and 1
"""
function log_scale10(x::Float64)
	return log10(1+99*x)/2
end

"""
    log_scale2(x::Float64)

In Linear Axis represenatation, values between 0-1 are linear distributed.
Due to the Logarithmfunction, we need to distribute the values with the given log values to match the axis

### Input:
- value x, distributed between 0 and 1
### Output:
- the log2 distribution, beween 0 and 1
"""
function log_scale2(x::Float64)
	return log2(1 + 3 * x) / 2
end

"""
    draw_axis(
		scene,
		width::Number,
		height::Number,
		offset::Number,
		limits,
		labels,
		numberFeatures::Number,
		scale_list
	)

Draws the Axis/Feature vertical Axis Lines on the given Scene

"""
function draw_axis(
    scene,
	width::Number,
	height::Number,
	offset::Number,
	limits,
	labels,
	numberFeatures::Number,
	scale_list
	)
	for i in 1:numberFeatures
		# x will be used to split the Scene for each feature
		x = numberFeatures==1 ? width/2 : (i - 1) / (numberFeatures - 1) * width

		# get default
		def = Makie.default_attribute_values(Axis, nothing)

		# LineAxis will create one Axis Vertical, for each Feature one Axis
		axis = Makie.LineAxis(
			scene,
			limits = limits[i],
			dim_convert = Makie.NoDimConversion(),
               # the lowest and highest point to maximize the Axis from Bottom to Top
			endpoints = Point2f[(offset + x, offset), (offset + x, offset + height)],
			tickformat = Makie.automatic,
			spinecolor = :black,
			spinevisible = true,
			labelfont = def[:ylabelfont],
			labelrotation = def[:ylabelrotation],
			labelvisible = false,
			ticklabelfont = def[:yticklabelfont],
			ticklabelsize = def[:yticklabelsize],
			minorticks = def[:yminorticks],
			scale = scale_list[i]
		)

		# Create Lable for the Axis
		axis_title!(
			scene,
			axis.attributes.endpoints,
			string(labels[i]);
			titlegap = def[:titlegap],
		)
	end
end


"""

	axis_title!(
		scene,
		endpoints::Observable,
		title::String;
		titlegap = Observable(4.0f0),
	)

This Function will create the Axis Label for a Axis

"""
function axis_title!(
    scene,
    endpoints::Observable,
    title::String;
    titlegap = Observable(4.0f0),
)
	# calculate the Position
    titlepos = lift(endpoints, titlegap) do a, titlegap
        x = a[1][1]
        y = a[2][2] + titlegap
        Point2(x, y)
    end

	# create the Title
    text!(
        scene,
        title,
        position = titlepos,
        align = (:center, :bottom),
        space = :data,
        inspectable = false,
    )
end


"""
    interpolate(last_x::Float64, current_x::Float64, last_y::Float64, current_y::Float64, x::Float64)::Float64

Interpolates the Y Value between the given current/last(x/y) point with the given x value.

### Input:
- old and New Coordinate (x/y Value)
- current x Value
### Output:
- current, interpolated y Value
"""
function interpolate(last_x::Float64, current_x::Float64, last_y::Float64, current_y::Float64, x::Float64)::Float64

	# calculate the % of Pi related to x between two x points
	x_pi = (x - last_x)/(current_x - last_x) * π

	# calculate the % difference between both x Values
	y_scale = 0.5-0.5*cos(x_pi) #between 0-1

	return last_y + y_scale * (current_y - last_y)

end

end