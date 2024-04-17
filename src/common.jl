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

import GeoDataFrames as GDF
import GeoFormatTypes as GFT
import ArchGDAL as AG

# Define constants for script
DATA_DIR = "../data"
OUTPUT_DIR = "../output"

"""
    plot_map(gdf::DataFrame; geom_col::Symbol=:geometry)

Convenience plot function.

# Arguments
- `gdf` : GeoDataFrame
- `geom_col` : Column name holding geometries to plot
"""
function plot_map(gdf::DataFrame; geom_col::Symbol=:geometry)
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

    plottable = GeoMakie.geo2basic(AG.forceto.(gdf[!, geom_col], AG.wkbPolygon))
    poly!(ga, plottable)

    # Need to auto-set limits explicitly, otherwise tick labels don't appear properly (?)
    # xlims!(ga)
    # ylims!(ga)
    # autolimits!(ga)

    display(f)

    return f, ga
end

"""
    find_intersections(
        x::DataFrame,
        y::DataFrame,
        xid::Symbol,
        yid::Symbol,
        ygeom_col::Symbol=:geometry;
        proportion::Bool=false,
        )

Find the areas of y that intersect with each polygon in x.
'rel_areas' contains corresponding yid for each intersecting polygon in x (can then be joined to x).
If Proportion = true: polygons of y are only chosen if the intersection with x is > 50% the area of x.
(Default: if proportion = false: the polygon of y that intersects the most area of x will be chosen).

# Arguments
- `x` : GeoDataFrame
- `y` : GeoDataFrame
- `xid` : Column name holding unique IDs for x geometries (referred to as GBRMPA_ID in rel_areas)
- `yid` : Column name holding variable of interest for y geometries
- `ygeom_col` : Column name holding geometries in y
- `proportion` : Only select y polygons if the intersection with x polygon is > 50% of x polygon area
"""

function find_intersections(
    x::DataFrame,
    y::DataFrame,
    xid::Symbol,
    yid::Symbol,
    ygeom_col::Symbol=:geometry;
    proportion::Bool=false,
    )
    rel_areas = DataFrame(GBRMPA_ID = [], area_ID = [])

    if proportion
        for i in 1:size(x,1)
        reef_poly = x[i,:]
        intersecting = DataFrame(GBRMPA_ID = [], area_ID = [], inter_area = [])

            for j in 1:size(y,1)
            interest_area = y[j,:]

                if AG.intersects(reef_poly.geometry, interest_area[ygeom_col])
                    inter_area = AG.intersection(reef_poly.geometry, interest_area[ygeom_col])
                    inter_area = AG.geomarea(inter_area)
                    prop_area = inter_area/AG.geomarea(reef_poly.geometry)
                    if prop_area >= 0.5
                        push!(intersecting, [x[i, xid], y[j, yid],inter_area])
                    else push!(intersecting, [ missing , missing, missing])
                    end
                else push!(intersecting, [ x[i,xid] , missing, missing])
                end
            end
            if all(ismissing,intersecting.area_ID)
                push!(rel_areas, [intersecting[1,xid], intersecting[1,:area_ID]])
            else
                dropmissing!(intersecting)
                push!(rel_areas, [intersecting[findmax(intersecting.inter_area)[2],xid],
                intersecting[findmax(intersecting.inter_area)[2],:area_ID]])
            end
        end
    else
        for i in 1:size(x,1)
            reef_poly = x[i,:]
            intersecting = DataFrame(GBRMPA_ID = [], area_ID = [], inter_area = [])

            for j in 1:size(y,1)
                interest_area = y[j,:]

                if AG.intersects(reef_poly.geometry, interest_area[ygeom_col])
                    inter_area = AG.intersection(reef_poly.geometry, interest_area[ygeom_col])
                    inter_area = AG.geomarea(inter_area)
                    prop_area = inter_area/AG.geomarea(reef_poly.geometry)
                    push!(intersecting, [x[i, xid], y[j, yid],prop_area])

                else push!(intersecting, [ x[i,xid] , missing, missing])
                end
            end
            if all(ismissing,intersecting.area_ID)
                push!(rel_areas, [intersecting[1,xid], intersecting[1,:area_ID]])
            else
                dropmissing!(intersecting)
                push!(rel_areas, [intersecting[findmax(intersecting.inter_area)[2],xid],
                intersecting[findmax(intersecting.inter_area)[2],:area_ID]])
            end
        end
    end
    return rel_areas
end

"""
    find_latest_file(dir::String)
    Function that finds the latest file in a directory with the date format YYYY-mm-dd-THH-SS.
    Intended to find the latest rrap_shared_lookup output file for input into the next script.

# Arguments
- `dir` : Target directory string.
"""
function find_latest_file(dir::String)
    files = readdir(dir)
    files = files[contains.(files, "rrap_shared_lookup")]
    timestamps = map(f -> Dates.DateTime(chop(f, head=19, tail=5), "YYYY-mm-dd-THH-SS"), files)
    latest = files[argmax(timestamps)]
    return latest
end
