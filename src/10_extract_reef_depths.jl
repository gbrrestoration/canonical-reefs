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

canonical_dataset = find_latest_file(OUTPUT_DIR)
gbr_features = GDF.read(canonical_dataset)

# Values are negative so need to flip direction
# Nominal value are: min, mean, median, max, std
summary_func(x) = (length(unique(x)) > 1) ? [-maximum(x), -mean(x), -median(x), -minimum(x), std(x)] : first(x)

# Using SharedArrays now as we might move to multi-core processing
# although using GPUs is an option...
depths = SharedArray(zeros(Float64, size(gbr_features, 1), 5))
errored_empty = SharedArray(zeros(Int64, size(gbr_features, 1)))

for reg in REGIONS
    @info "Extracting depths for $(reg)"

    src_bathy_path = first(glob("*.tif", joinpath(BATHY_DATA_DIR, "bathy", reg)))
    src_bathy = Raster(src_bathy_path, mappedcrs=EPSG(4326), lazy=true)

    proj_str = ProjString(AG.toPROJ4(AG.importWKT(crs(src_bathy).val; order=:compliant)))

    # Ensure polygon types match
    region_features = GDF.read(region_path)

    # Force CRS to match raster data
    region_features.geometry = AG.reproject(region_features.SHAPE, EPSG(4326), proj_str; order=:trad)
    region_features[!, :geometry] = Vector{AG.IGeometry}(AG.forceto.(region_features.geometry, AG.wkbMultiPolygon))

    reg_idx = occursin.(reg[1:3], region_features.AREA_DESCR)
    tgt_region = region_features.geometry[reg_idx]

    # Reload GBR reef set
    # Reprojection overwrites data, and we cannot `copy()` as it copies the pointers.
    gdf = GDF.read(canonical_dataset)
    gdf[!, :geometry] = Vector{AG.IGeometry}(AG.forceto.(gdf.geometry, AG.wkbMultiPolygon))

    target_geoms = gdf.geometry
    target_geoms = AG.reproject(target_geoms, EPSG(4326), proj_str; order=:trad)

    feature_match_ids = unique(findall(GDF.intersects.(tgt_region, target_geoms)))

    Threads.@threads for id in feature_match_ids
        try
            depths[id, :] .= zonal(summary_func, src_bathy; of=target_geoms[id])
        catch err
            if (err isa MethodError) || (err isa ArgumentError)
                # Raises MethodError when `target_geoms` is empty
                # Raises ArgumentError where `zonal()` produces `Missing` (no data)
                msg = "MethodError or ArgumentError on $(id) - likely a feature with no overlap"
                @info msg collect(gdf[id, [:UNIQUE_ID, :reef_name]])
                errored_empty[id] = 1
                continue
            end

            @info "Error on $(id)"
            rethrow(err)
        end
    end
end

# Threads on inner loop (12 threads)
# 88.003740 seconds (29.41 M allocations: 7.957 GiB, 1.54% gc time, 2.32% compilation time)

depths[errored_empty .> 0, :] .= 7.0  # Set to ReefMod default value if nothing found.

# Set quality flags:
# 0 = no error (does not indicate polygons that only partially overlap a target reef!)
# 1 = no overlap error (value set to 7m)
# 2 = minimum value above sea level (no change made, just a flag)
errored_empty[depths[:, 1] .< 0.0] .= 2

gdf = GDF.read(canonical_dataset)
insertcols!(
    gdf,
    ([:depth_min, :depth_mean, :depth_med, :depth_max, :depth_std, :depth_qc] .=> [1,2,3,4,5,6])...
)
gdf[!, [:depth_min, :depth_mean, :depth_med, :depth_max, :depth_std]] = depths
gdf[!, :depth_qc] .= errored_empty

GDF.write(joinpath(OUTPUT_DIR, "canonical_gbr_$(today()).gpkg"), gdf; geom_columns=(:geometry, ))
