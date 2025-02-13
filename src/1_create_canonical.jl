"""
Create a standardized geopackage file for use as a canonical/reference dataset,
incorporating data from:

- GBRMPA Reef Feature dataset:
    - https://data.gov.au/dataset/ds-dga-51199513-98fa-46e6-b766-8e1e1c896869/details
    - The metadata for the data.gov.au entry states it has been "Updated 16/08/2023"
- A. Cresswell's Lookup table `GBR_reefs_lookup_table_Anna_update_2024-03-06.[csv/xlsx]`
  This is referred to as the AC lookup table.
- `id_list_2023_03_30.csv` from ReefMod Engine 2024-06-13 (v1.0.33)

See project README.md for further details.
"""

include("common.jl")

# Load datasets
ac_lookup = CSV.read(joinpath(DATA_DIR, "GBR_reefs_lookup_table_Anna_update_2024-03-06.csv"), DataFrame, missingstring="NA")
rme_features = GDF.read(joinpath(DATA_DIR,"reefmod_gbr.gpkg"))
rme_ids = CSV.read(
    joinpath(DATA_DIR, "id_list_2023_03_30.csv"),
    DataFrame,
    header=false,
    comment="#"
)
gbr_features = GDF.read(joinpath(DATA_DIR, "gbr_features", "Great_Barrier_Reef_Features.shp"))

# Standardize name format (strips the single quote from strings)
# and turn Pascal case to snake case, use lower case where appropriate, etc.
# Have to do this in two steps as the Dictionary types have to be the same
# i.e., cannot mix string and symbols keys
rename!(ac_lookup, Dict("Cscape cluster" => :cscape_cluster))
rename!(ac_lookup, Dict(:Tempgrowth => :temp_growth, :LTMP_reef => :is_LTMP_reef))

# Attach correct names to rme_ids from id_list_2023_03_30.csv
id_list_names = ["reef_id", "area_km2", "sand_proportion", "shelf_position"]
rename!(rme_ids, ["Column$(i)" => col_name for (i, col_name) in enumerate(id_list_names)])

# Find UNIQUE IDs in RME dataset that do not appear in GBRMPA dataset
mismatched_unique = findall(.!(rme_features.UNIQUE_ID .∈ [gbr_features.UNIQUE_ID]))

# IDs of the mismatched reefs
# rme_features.UNIQUE_ID[mismatched_unique]

# These missing ones are the same as noted above by their LTMP IDs
# These will be replaced with the revised IDs
updated_ID_mapping = Dict(
    "10-441" => "11-325",
    "11-288" => "11-244e",
    "11-303" => "11-244f",
    "11-310" => "11-244g",
    "11-311" => "11-244h",
)

matching_reefs = gbr_features.UNIQUE_ID .∈ Ref(rme_features.UNIQUE_ID)
matching_UNIQUE_IDs = gbr_features[matching_reefs, :UNIQUE_ID]
gbr_matched = gbr_features[matching_reefs, :]

# Add the five missing reefs
gbr_matched = vcat(gbr_matched, gbr_features[gbr_features.LABEL_ID.∈Ref(values(updated_ID_mapping)), :])

# Find and add the relevant IDs for the missing reefs
updated_idx = rme_features.LABEL_ID .∈ Ref(keys(updated_ID_mapping))
updated_reefs_rme_ids = rme_features[updated_idx, :UNIQUE_ID]

old_LABEL_IDs = vcat(gbr_features[matching_reefs, :LABEL_ID], rme_features[updated_idx, :LABEL_ID])
RME_LABEL_IDs = ifelse.(old_LABEL_IDs .== "20198", "20-198", old_LABEL_IDs)

old_UNIQUE_IDs = vcat(matching_UNIQUE_IDs, updated_reefs_rme_ids)

gbr_matched[!, :RME_UNIQUE_ID] = old_UNIQUE_IDs
gbr_matched[!, :RME_GBRMPA_ID] = RME_LABEL_IDs

# Start copying relevant columns
cols_of_interest = [:UNIQUE_ID, :LABEL_ID, :X_LABEL, :LOC_NAME_S, :RME_UNIQUE_ID, :RME_GBRMPA_ID]
output_features = gbr_matched[:, cols_of_interest]

# Standardize column names for ease of copying
cols_to_copy = [:cscape_cluster, :is_LTMP_reef, :EcoRRAP_photogrammetry_reef, :cscape_region, :temp_growth]
output_features = hcat(output_features, ac_lookup[:, cols_to_copy])

# Attach spatial data at the end of the dataframe
output_features = hcat(output_features, gbr_matched[:, [:X_COORD, :Y_COORD, :geometry]])

# Here we take a big leap of faith.
# The order indicated in AC's lookup table is said to match that of RME's
# so we replace UNIQUE_ID with RME's to ensure row order remains identical.
ac_lookup[:, :UNIQUE_ID] = rme_features.UNIQUE_ID

# Find the position for each UNIQUE_ID entry.
matching_order = reduce(
    vcat,
    [findall(rme_uid -> rme_uid == ac_uid, output_features.RME_UNIQUE_ID)
     for ac_uid in ac_lookup.UNIQUE_ID]
)

# Reorder to match AC lookup
output_features = output_features[matching_order, :]
@assert all(output_features.RME_UNIQUE_ID .== ac_lookup.UNIQUE_ID)

# Rename to standardized format
rename!(
    output_features,
    Dict(
        :LABEL_ID => :GBRMPA_ID,
        :X_LABEL => :LTMP_ID,
        :LOC_NAME_S => :reef_name,
        :X_COORD => :LON,
        :Y_COORD => :LAT
    )
)

# Standardize data types to string where appropriate
output_features[!, :is_LTMP_reef] = map(x -> x != "" ? parse(Int64, x) : 0, output_features[:, :is_LTMP_reef])
output_features[!, :is_LTMP_reef] = Int64.(output_features[!, :is_LTMP_reef])
output_features[!, :cscape_region] = map(x -> x != "" ? parse(Int64, x) : 0, output_features[:, :cscape_region])
output_features[!, :cscape_cluster] = map(x -> !ismissing(x) & (x != "") ? String(x) : "NA", output_features[:, :cscape_cluster])

# Convert any data marked as missing to "NA"
output_features .= ifelse.(ismissing.(output_features), "NA", output_features)

# Convert all String-type data to pure String type
# i.e., no types optimized for their length such as String7, String31, etc.
# (GeoDataFrames cannot handle these automatically yet)
string_cols = contains.(string.(typeof.(eachcol(output_features))), "String")
output_features[!, contains.(string.(typeof.(eachcol(output_features))), "String")] .= String.(output_features[:, string_cols])

# Convert area in km² to m²
output_features.ReefMod_area_m2 .= rme_ids[:, :area_km2] .* 1e6

# Calculate `k` area (1.0 - "ungrazable" area)
output_features.ReefMod_habitable_proportion .= 1.0 .- rme_ids[:, :sand_proportion]

# Reproject output_features from GDA94 EPSG4283 to GDA2020 EPSG7844 to match GBRMPA geohub data
output_features.geometry = AG.reproject(output_features.geometry, GI.crs(output_features[1,:geometry]), EPSG(7844); order=:trad)

# Save geopackage
GDF.write(joinpath(OUTPUT_DIR, "rrap_canonical_$(Dates.format(now(), DATE_FORMAT)).gpkg"), output_features; crs=GBRMPA_CRS)

# Save copy of map
f, ga = plot_map(output_features)
save(joinpath(FIGS_DIR, "rrap_mds_reefs_$(today()).png"), f)
