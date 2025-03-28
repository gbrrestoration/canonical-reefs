"""
Extracts depths for each reef of interest using:

- GBRMPA Reef features [TODO: Try Allen Atlas features]

- GBRMPA Bathymetry data (10m resolution)
  https://gbrmpa.maps.arcgis.com/home/item.html?id=f644f02ec646496eb5d31ad4f9d0fc64

- GBRMPA Region features for each management area

- ReefMod Reef IDs

- RRAP Shared Lookup

- [TODO] GBR regions (north / center / south)
"""

using StatsBase
using GeoFormatTypes: EPSG

using Rasters
using SharedArrays
using GeometryOps

include("common.jl")

REGIONS = String[
    "Townsville-Whitsunday",
    "Cairns-Cooktown",
    "Mackay-Capricorn",
    "FarNorthern",
]

# Get polygon of management areas
region_path = joinpath(
    DATA_DIR,
    "Great_Barrier_Reef_Marine_Park_Management_Areas_20_1685154518472315942.gpkg"
)

canonical_file = find_latest_file(OUTPUT_DIR)
gbr_features = GDF.read(canonical_file)

# Values are negative so need to flip direction
# Nominal value are: min, mean, median, max, std
function summary_func(x, pixel_area, id_area)
    prop_area = length(collect(x)) * pixel_area / id_area

    if length(collect(x)) > 1
        return [-maximum(x), -mean(x), -median(x), -minimum(x), std(x), prop_area]
    end

    return [-first(x), -first(x), -first(x), -first(x), -first(x), prop_area]
end

depths = zeros(Float64, size(gbr_features, 1), 6)
errored_empty = zeros(Int64, size(gbr_features, 1))

for reg in REGIONS
    @info "Extracting depths for $(reg)"

    src_bathy_path = first(glob("*.tif", joinpath(BATHY_DATA_DIR, "bathy", reg)))
    src_bathy = Raster(src_bathy_path; lazy=true)

    res = abs.(step.(dims(src_bathy, (X, Y))))
    pixel_area = res[1] * res[2]

    proj_str = ProjString(AG.toPROJ4(AG.importWKT(crs(src_bathy).val; order=:compliant)))

    # Ensure polygon types match
    region_features = GDF.read(region_path)

    # Force CRS to match raster data
    region_features.geometry = AG.reproject(region_features.SHAPE, EPSG(4326), proj_str; order=:trad)
    region_features[!, :geometry] = Vector{AG.IGeometry}(AG.forceto.(region_features.geometry, AG.wkbMultiPolygon))

    reg_idx = occursin.(reg[1:3], region_features.AREA_DESCR)
    tgt_region = region_features.geometry[reg_idx]

    # Reload GBR reef set
    # Important: Reloading the canonical dataset is intentional as reprojection overwrites
    # data, and we cannot use `copy()` as it copies the pointers, not the data itself.
    gdf_tmp = GDF.read(canonical_file)
    gdf_tmp[!, :geometry] = Vector{AG.IGeometry}(AG.forceto.(gdf_tmp.geometry, AG.wkbMultiPolygon))

    target_geoms = gdf_tmp.geometry
    target_geoms = AG.reproject(target_geoms, EPSG(4326), proj_str; order=:trad)

    feature_match_ids = unique(findall(GDF.intersects.(tgt_region, gdf_tmp.geometry)))

    Threads.@threads for id in feature_match_ids
        id_area = GeometryOps.area(target_geoms[id])
        try
            depths[id, :] .= zonal(x -> summary_func(x, pixel_area, id_area), src_bathy; of=target_geoms[id])
        catch err
            if (err isa MethodError) || (err isa ArgumentError)
                # Raises MethodError when `target_geoms` is empty
                # Raises ArgumentError where `zonal()` produces `Missing` (no data)
                msg = "MethodError or ArgumentError on $(id)\n"
                msg = msg * "Possibly a reef feature with no overlapping polygon"
                @info msg collect(gdf_tmp[id, [:UNIQUE_ID, :reef_name]])
                @info err
                errored_empty[id] = 1
                continue
            end

            @info "Error on $(id)"
            rethrow(err)
        end

        if depths[id, 1] < -5
            reef = collect(gdf_tmp[id, [:UNIQUE_ID, :reef_name]])
            @warn "$(reef) has a minimum depth value higher than 5m above sea level."
        end
    end
end

# Threads on inner loop (12 threads)
# 88.003740 seconds (29.41 M allocations: 7.957 GiB, 1.54% gc time, 2.32% compilation time)

# Set quality flags:
# 0 = no error (does not indicate polygons that only partially overlap a target reef!)
# 1 = no overlap error (value set to 7m)
# 2 = minimum value above sea level (no change made, just a flag)
# 3 = raster pixels cover < 5% of the reef polygon area (no change, just a flag)
errored_empty[depths[:, 6] .< 0.05] .= 3
errored_empty[depths[:, 1] .< 0.0] .= 2

# Set depth vals to ReefMod default value if nothing found.
# ISSUE: If the bathymetry layer is blank it most likely means the reef is deeper than the visible extent and more likely to be >20m
# Could do the same for other QC flags too
depths[errored_empty .∈ [[1,3]] , 1:5] .= 7.0

gdf = GDF.read(canonical_file)

# Remove existing columns if needed
if "depth_min" in names(gdf)
    gdf = gdf[!, Not([:depth_min, :depth_mean, :depth_med, :depth_max, :depth_std, :depth_qc])]
end

# Have to check for this column separately
if "depth_rast_prop" in names(gdf)
    gdf = gdf[!, Not([:depth_rast_prop])]
end

# Re-insert the new columns
try
    insertcols!(
        gdf,
        ([:depth_min, :depth_mean, :depth_med, :depth_max, :depth_std, :depth_qc, :depth_rast_prop] .=> [1,2,3,4,5,6,7])...
    )
catch err
    if !(err isa LoadError)
        rethrow(err)
    end
end

gdf[!, [:depth_min, :depth_mean, :depth_med, :depth_max, :depth_std, :depth_rast_prop]] = depths
gdf[!, :depth_qc] .= errored_empty

GDF.write(canonical_file, gdf; geom_columns=(:geometry, ), crs=GBRMPA_CRS)
