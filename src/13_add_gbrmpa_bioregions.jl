include("common.jl")

OVERLAP_THRESHOLD::Float64 = 0.5

# GBRMPA bioregion geopackage
bioregions_gpkg = GDF.read(BIOREGION_GPKG_PATH)

# load existing canonincal_gpkg to edit
canonical_file = find_latest_file(OUTPUT_DIR)
canonical_gpkg = GDF.read(canonical_file)

"""Get the proportion of canonical reef area covered by a bioregion reef polygon."""
function intersection_proportion(
    canonical_geom::AG.IGeometry,
    canonical_geom_area::Float64,
    bioregion_geom::AG.IGeometry
)
    if !AG.intersects(canonical_geom, bioregion_geom)
        return 0.0
    end

    intersection_geom = AG.intersection(canonical_geom, bioregion_geom)
    intersecting_area::Float64 = AG.geomarea(intersection_geom)

    return intersecting_area / canonical_geom_area
end

canonical_geom_areas::Vector{Float64} = [
    AG.geomarea(geom) for geom in canonical_gpkg.geometry
]

canonical_bioregion_idxs = [
    findmax(
        x->intersection_proportion(c_geom, c_geom_area, x),
        bioregions_gpkg.geometry
    ) for (c_geom, c_geom_area) in zip(canonical_gpkg.geometry, canonical_geom_areas)
]

# Get proportion of polygon overlapping with bioregion polygon
canonical_overlap_props = getindex.(canonical_bioregion_idxs, Ref(1))
# For each canonical reef get the index of the corresponding bioregion idx
canonical_bioregion_idxs = getindex.(canonical_bioregion_idxs, Ref(2))
# Canonical locations for which there was less the 75% polygon area overlap
canonical_no_assign_mask = 0.0 <= canonical_overlap_props <= OVERLAP_THRESHOLD
# get bioregion for each canonical reef
canonical_bioregions = bioregions_gpkg.BIOREGION[canonical_bioregion_idxs]
canonical_bioregions[canonical_no_assign_mask] = -1
# write bioregions features to canonical geopackage file
canonical_gpkg[!, :GBRMPA_BIOREGION] .= canonical_bioregions
GDF.write(canonical_file, canonical_gpkg; crs=GBRMPA_CRS)
