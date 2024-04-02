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

    return f
end
