include("common.jl")

# Load required data.
canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)
cots_priority = CSV.read(joinpath(DATA_DIR, "CoCoNet_CoTS_control_reefs_2024.csv"), DataFrame, missingstring="NA")

# Temporarily fix incorrect GBRMPA_ID to match
RRAP_lookup.GBRMPA_ID = ifelse.(RRAP_lookup.GBRMPA_ID .== "20198", "20-198", RRAP_lookup.GBRMPA_ID)

# Format data.
rename!(
    cots_priority,
    Dict(
        "LAT"=>:cots_LAT,
        "LON"=>:cots_LON,
        "ReefID"=>:GBRMPA_ID,
        "Priority"=>:priority
        )
    )
cots_priority = cots_priority[:, [:GBRMPA_ID, :cots_LON, :cots_LAT, :priority]]

# Adding cots priority into RRAP_lookup.
RRAP_lookup = leftjoin(RRAP_lookup, cots_priority, on=:GBRMPA_ID, order=:left)

# Cross-checking that the GBRMPA_ID from RRAP_lookup matches from cots_priority (within 100m - rounded values).
matching = DataFrame(match_lon=[], match_lat=[])
match_lon = (RRAP_lookup.cots_LON .< RRAP_lookup.LON .+ 0.001) .& (RRAP_lookup.cots_LON .> RRAP_lookup.LON .- 0.001)
match_lat = (RRAP_lookup.cots_LAT .< RRAP_lookup.LAT .+ 0.001) .& (RRAP_lookup.cots_LAT .> RRAP_lookup.LAT .- 0.001)
matching = DataFrame(match_lon=match_lon, match_lat=match_lat)
spat_mismatch = RRAP_lookup[(findall(skipmissing(.!matching.match_lon))),:]

# Visual check of how close mismatching coords are to original coords.
reef_plot, ga = plot_map(spat_mismatch)
scatter!(ga, spat_mismatch.LON, spat_mismatch.LAT, markersize = 8)
scatter!(ga, spat_mismatch.cots_LON, spat_mismatch.LAT, markersize = 6)
save(joinpath(FIGS_DIR, "rrap_cots_data_mismatching_locations_$(today()).png"), reef_plot)

# Format output data.
RRAP_lookup = select!(RRAP_lookup, Not(:cots_LON, :cots_LAT))
rename!(RRAP_lookup, Dict(:priority=>:COTS_priority))
RRAP_lookup.COTS_priority .= ifelse.(ismissing.(RRAP_lookup.COTS_priority), "NA", RRAP_lookup.COTS_priority)
RRAP_lookup.COTS_priority = convert.(String, RRAP_lookup.COTS_priority)

# Revert incorrect GBRMPA_ID to match data provided by GBRMPA
RRAP_lookup.GBRMPA_ID = ifelse.(RRAP_lookup.GBRMPA_ID .== "20-198", "20198", RRAP_lookup.GBRMPA_ID)

# Replace canonical file with updated data
GDF.write(canonical_file, RRAP_lookup; crs=GBRMPA_CRS)
