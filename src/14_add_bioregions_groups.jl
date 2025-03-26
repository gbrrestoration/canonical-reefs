include("common.jl")

bioregions_gpkg = GDF.read(BIOREGION_GPKG_PATH)

# load existing canonical gpkg to edit
canonical_file = find_lastest_file(OUTPUT_DIR)
canonical_gpkg = GDF.read(canonical_file)

# Load LTMP Manta Tow data
manta_tow_data = GDF.read()

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

# Pre-compute area of each canonical reef polygon to avoid duplicate computation
canonical_geom_areas::Vector{Float64} = [
    AG.geomarea(geom) for geom in canonical_gpkg.geometry
]

# Calculate the overlap between canonical reef and bioregion reef overlaps
canon_bioregion_overlap::Vector{Tuple{Float64, Int64}} = [
    findmax(
        x->intersection_proportion(c_geom, c_geom_area, x),
        bioregions_gpkg.geometry
    ) for (c_geom, c_geom_area) in zip(canonical_gpkg.geometry, canonical_geom_areas)
]

# Get proportion of polygon overlapping with bioregion polygon
canonical_overlap_props = getindex.(canonical_bioregion_idxs, Ref(1))
# For locations for which there was an overlap, assign the bioregions
canonical_bioregion_idxs = getindex.(canonical_bioregion_idxs, Ref(2))
# Canonical locations where there are no bioregion polygons overlapping
canonical_no_overlap_mask = canonical_overlap_props .!= 0.0

# For reefs with no overlapping bioregion polygon, find the closest bioregion polygon
for (canon_idx, overlap) in enumerate(canonical_overlap_props,)
    if overlap != 0.0
        continue
    end

    dists = [
        AG.distance(canonical_gpkg.geometry[canon_idx], bioreg_geom)
        for bioreg_geom in bioregions_gpkg.geometry
    ]
    canonical_bioregion_idxs = argmin(dists)
end

# extract bioregions for each canonical reef
canonical_bioregions = bioregions_gpkg.BIOREGION[canonical_bioregion_idxs]

"""For a given LTMP Manta Tow point, find the closest bioregion reef."""
function get_ltmp_idx(ltmp_pt, bioregs)
    possible_idx = findfirst(x -> AG.contains(x, ltmp_pt), bioregs.geometry)
    if isnothing(possible_idx)
        dists = [AG.distance(ltmp_pt, bio_geom) for bio_geom in bioregs.geometry]
        possible_idx = argmin(dists)
        if dists[possible_idx] > 1.0
            return nothing
        end
    end
    return possible_idx
end

bioregion_ltmp_idx = [
    get_ltmp_idx(pt, bioregions_gpkg) for pt in manta_tow_data.geometry
]

# Get the bioregion for each LTMP reef.
ltmp_bioregion = [
    isnothing(idx) ? -1 : bioregions_gpkg[idx, :BIOREGION] for idx in bioregion_ltmp_idx
]

"""Get the length of time between the first and last observations."""
function get_temporal_range(dfr::DataFrameRow)
    first_yr = findfirst(x -> !ismissing(x), dfr)
    last_yr  = findlast(x -> !ismissing(x), dfr)

    if isnothing(first_yr) || isnothing(last_yr)
        return 0
    end

    return parse(Int64, String(last_yr)) - parse(Int64, String(first_yr))
end

"""Count the number of non-missing observations in a dataframe row."""
function count_data_points(dfr::DataFrameRow)::Int64
    return count((!).(ismissing(collect(dfr))))
end

"""
    enough_data(df::DataFrame)

Locations with at least 4 observatins spanning at least 10 years are deemed to have
sufficient data for calibration. Return a mask indicating which manta tow locations meet
these requirements.
"""
function enough_data(df::DataFrame)
    return [count_data_points(dfr) >= 4 && get_temporal_range(dfr) >= 10 for dfr in eachrow(df)]
end

# column index of 2008 year
yr_2008_idx = findfirst(x -> x == "2008", names(manta_tow_data))
# locations with enough data for calibration over 2008-2022
locs_enough_data = enough_data(manta_tow_data[:, yr_2008_idx:end])

all_bioregs = unique(bioregions_gpkg.BIOREGION)

ltmp_counts = zeros(Int64, length(all_bioregs))

for (idx, bioreg) in enumerate(all_bioregs)
    bioreg_mask =  ltmp_bioregion .== bioreg
    msk = bioreg_mask .&& locs_enough_data
    ltmp_counts[idx] = count(msk)
end

enough_data_mask = fill(false, 3806)
for (bioreg, cnt) in zip(all_bioregs, ltmp_counts)
    if cnt >= 4
        enough_data_mask .|= canonical_bioregions .== bioreg
    end
end

"""Given a two lists of geometries, construct a distance matrix between the two lists."""
function construct_distance_matrix(geoms1, geoms2)::Matrix{Float64}
    n1::Int64 = length(geoms1)
    n2::Int64 = length(geoms2)

    dists::Matrix{Float64} = Matrix{Float64}(undef, n1, n2)
    for i in 1:n1, j in 1:n2
        dists[i, j] = AG.distance(geoms1[i], geoms2[j])
    end

    return dists
end

"""
Quantify the distance between two bioregions by taking the 10% quantile of all distances
between locations. The distances are only meant to be used in a relative manner.
"""
function bioregion_distance(
    b1::Int64,
    b2::Int64;
    canonical_bioregions=canonical_bioregions,
    canonical_gpkg=canonical_gpkg
)::Float64
    bio1::DataFrame = canonical_gpkg[canonical_bioregions .== b1, :]
    bio2::DataFrame = canonical_gpkg[canonical_bioregions .== b2, :]

    dists_mats = construct_distance_matrix(bio1.geom, bio2.geom)

    return quantile(vec(dists_mats), 0.1)
end

bioregion_no_data = ltmp_counts .< 4

# Grouped bioregions guarenteeing enough data
bioregion_assignment = zeros(Int64, length(all_bioregs))

# bioregions with sufficient ltmp data are assignmed to themselves
bioregion_assignment[(!).(bioregion_no_data)] = all_bioregs[(!).(bioregion_no_data)]

for (idx, bioreg) in enumerate(all_bioregs)
    if bioregion_assignment[idx] != 0
        continue
    end
    # find the closest bioregion with enough data
    min_dist = 10000
    for bioreg_w_data in all_bioregs[(!).(bioregion_no_data)]
        bioreg_dist = bioregion_distance(bioreg, bioreg_w_data)
        if bioreg_dist < min_dist
            bioregion_assignment[idx] = bioreg_w_data
            min_dist = bioreg_dist
        end
    end
end

"""
    orginal_bio_to_assignmed_bio(original_bio::Int64; original_bio_regs=all_bioregs, assigned_bio_regs=bioregion_assignment)::Int64

Convert a bioregion to the reassigned bioregion.
"""
function orginal_bio_to_assignmed_bio(
    original_bio::Int64;
    original_bio_regs=all_bioregs,
    assigned_bio_regs=bioregion_assignment
)::Int64
    idx::Int64 = findfirst(x->x==original_bio, original_bio_regs)
    if isnothing(idx)
        throw(ArgumentError("Bioregion $(idx) not found in original bioregions"))
    end
    return assigned_bio_regs[idx]
end

canonical_assigned_bioregions = orginal_bio_to_assignmed_bio.(canonical_bioregions)
