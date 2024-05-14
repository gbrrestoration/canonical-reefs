using Glob
using TOML

using
    CSV,
    Dates,
    DataFrames

using
    GLMakie,
    GeoMakie

using
    Statistics,
    Bootstrap

using Rasters
import GeoDataFrames as GDF
import GeoFormatTypes as GFT
import ArchGDAL as AG
import GeoInterface as GI

# Define constants for script
DATA_DIR = "../data"
OUTPUT_DIR = "../output"
DATE_FORMAT = "YYYY-mm-dd-THH-MM-SS"
GBRMPA_CRS = GFT.EPSG(7844)

CONFIG = Dict()
BATHY_DATA_DIR = ""
try
    global CONFIG = TOML.parsefile("./.config.toml")
    global BATHY_DATA_DIR = CONFIG["bathy"]["BATHY_DATA_DIR"]
catch
    @warn "No configuration file found!"
end

function _convert_plottable(gdf::Union{DataFrame, DataFrameRow}, geom_col::Symbol)
    local plottable
    try
        if gdf isa DataFrame
            plottable = GeoMakie.geo2basic(AG.forceto.(gdf[!, geom_col], AG.wkbPolygon))
        else
            plottable = GeoMakie.geo2basic(AG.forceto(gdf[geom_col], AG.wkbPolygon))
        end
    catch
        # Column is already in a plottable form, or some unrelated error occurred
        if gdf isa DataFrame
            plottable = gdf[:, geom_col]
        else
            plottable = [gdf[geom_col]]
        end
    end

    return plottable
end

"""
    plot_map(gdf::DataFrame; geom_col::Symbol=:geometry, color_by::Symbol)

Convenience plot function.

# Arguments
- `gdf` : GeoDataFrame
- `geom_col` : Column name holding geometries to plot
- `color_by` : Column name holding factor to color reefs by (e.g. :management_area)
"""
function plot_map(gdf::Union{DataFrame, DataFrameRow}; geom_col::Symbol=:geometry)
    f = Figure(; size=(600, 900))
    ga = GeoAxis(
        f[1,1];
        dest="+proj=latlong +datum=WGS84",
        xlabel="Longitude",
        ylabel="Latitude",
        xticklabelpad=15,
        yticklabelpad=40,
        xticklabelsize=10,
        yticklabelsize=10,
        aspect=AxisAspect(0.75),
        xgridwidth=0.5,
        ygridwidth=0.5,
    )

    plottable = _convert_plottable(gdf, geom_col)
    poly!(ga, plottable)

    display(f)

    return f, ga
end

function plot_map!(ga::GeoAxis, gdf::DataFrame; geom_col=:geometry, color=nothing)::Nothing

    plottable = _convert_plottable(gdf, geom_col)
    if !isnothing(color)
        poly!(ga, plottable, color=color)
    else
        poly!(ga, plottable)
    end

    # Set figure limits explicitly
    xlims!(ga)
    ylims!(ga)

    return nothing
end

function plot_map!(gdf::DataFrame; geom_col=:geometry, color=nothing)::Nothing
    return plot_map!(current_axis(), gdf; geom_col=geom_col, color=color)
end

function plot_map(Union{DataFrame, DataFrameRow}; geom_col::Symbol=:geometry, color_by::Symbol)
    f = Figure(; size=(600, 900))
    ga = GeoAxis(
        f[1,1];
        dest="+proj=latlong +datum=WGS84",
        xlabel="Longitude",
        ylabel="Latitude",
        xticklabelpad=15,
        yticklabelpad=40,
        xticklabelsize=10,
        yticklabelsize=10,
        aspect=AxisAspect(0.75),
        xgridwidth=0.5,
        ygridwidth=0.5,
    )

    plottable = _convert_plottable(gdf, geom_col)

    palette = ColorSchemes.tableau_20.colors
    color_indices = groupindices(groupby(gdf, color_by))

    poly!(ga, plottable, color = palette[color_indices])

    axislegend()
    display(f)
end

"""
    find_intersections(
        x::DataFrame,
        y::DataFrame,
        x_id::Symbol,
        y_id::Symbol,
        y_geom_col::Symbol=:geometry;
        proportion::Bool=false,
    )::DataFrame

Find the areas of `y` that intersect with each polygon in `x`.
`rel_areas` contains corresponding `y_id` for each intersecting polygon in x (can then be
joined to `x`).

If `proportion = true`: polygons of `y` are only chosen if the intersection with `x` is >
50% the area of `x`.

# Arguments
- `x` : The target GeoDataFrame to compare with
- `y` : GeoDataFrame containing polygons to match against `x`
- `xid` : Column name holding unique IDs for x geometries (referred to as GBRMPA_ID in rel_areas)
- `yid` : Column name holding variable of interest for y geometries
- `y_geom_col` : Column name holding geometries in y
- `proportion` : Only select y polygons if the intersection with x polygon is > 50% of x polygon area
                 (default: `false`).
"""
function find_intersections(
    x::DataFrame,
    y::DataFrame,
    x_id::Symbol,
    y_id::Symbol,
    y_geom_col::Symbol=:geometry;
    proportion::Bool=false
)::DataFrame
    rel_areas = DataFrame(
        [Vector{Any}(missing, size(x, 1)) for _ in 1:2],
        [:GBRMPA_ID, :area_ID]
    )

    for (x_i, reef_poly) in enumerate(eachrow(x))
        intersecting = DataFrame(
            [Vector{Any}(missing, size(y, 1)) for _ in 1:3],
            [:GBRMPA_ID, :area_ID, :inter_area]
        )

        for (y_i, interest_area) in enumerate(eachrow(y))
            if AG.intersects(reef_poly.geometry, interest_area[y_geom_col])
                inter_area = AG.intersection(
                    reef_poly.geometry, interest_area[y_geom_col]
                )

                inter_area = AG.geomarea(inter_area)
                if proportion
                    prop_area = inter_area / AG.geomarea(reef_poly.geometry)

                    if prop_area >= 0.5
                        data = [reef_poly[x_id], interest_area[y_id], inter_area]

                    else
                        data = [missing, missing, missing]
                    end
                else
                    data = [reef_poly[x_id], interest_area[y_id], inter_area]
                end
            else
                data = [reef_poly[x_id], missing, missing]
            end

            intersecting[y_i, :] = data
        end

        if all(ismissing, intersecting.area_ID)
            x_data = [intersecting[1, x_id], intersecting[1, :area_ID]]
        else
            dropmissing!(intersecting)
            max_inter_area = argmax(intersecting.inter_area)
            x_data = [intersecting[max_inter_area, x_id], intersecting[max_inter_area, :area_ID]]
        end

        rel_areas[x_i, :] = x_data
    end

    return rel_areas
end

"""
    _get_file_timestamp(file_path, dt_length)::DateTime

Extract the timestamp from a given file name.
"""
function _get_file_timestamp(file_path, dt_length)::DateTime
    # Get name of file without extension
    filename = splitext(basename(file_path))[1]

    local fn_timestamp
    try
        fn_timestamp = Dates.DateTime(filename[end-(dt_length-1):end], DATE_FORMAT)
    catch err
        if !(err isa ArgumentError)
            rethrow(err)
        end

        # Otherwise, some unexpected date format was encountered so we assign an
        # very early date/time.
        fn_timestamp = Dates.DateTime("1900-01-01-T00-00-00", DATE_FORMAT)
    end

    # Return datetime stamp
    return fn_timestamp
end

"""
    find_latest_file(
        target_dir::String;
        prefix::String="rrap_canonical",
        ext::String="gpkg"
    )::String

Identify the latest output file in a directory based on the timestamp included in the
file name (default: `YYYY-mm-dd-THH-MM-SS`). Intended to find the latest output file for
input into the next script.

# Arguments
- `target_dir` : Target directory
- `prefix` : prefix of target file
- `ext` : the file extension

# Returns
Path to latest output file.
"""
function find_latest_file(
    target_dir::String;
    prefix::String="rrap_canonical",
    ext::String="gpkg"
)::String
    # Get list of files matching the given pattern
    candidate_files = glob("$(prefix)*.$(ext)", target_dir)

    timestamps = map(f -> _get_file_timestamp(f, length(DATE_FORMAT)), candidate_files)
    latest = candidate_files[argmax(timestamps)]

    return latest
end
