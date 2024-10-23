include("common.jl")

# Load required data.
canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)
cots_priority = CSV.read(joinpath(DATA_DIR, "TargetReefs_202425.csv"), DataFrame)

# Format input data.
rename!(
    cots_priority,
    Dict(
        "Latitude"=>:cots_LAT,
        "Longitude"=>:cots_LON,
        "ReefID"=>:GBRMPA_ID,
        "RankForAction"=>:priority
        )
    )
cots_priority = cots_priority[:, [:GBRMPA_ID, :cots_LON, :cots_LAT, :priority]]

# Adding cots priority into RRAP_lookup.
RRAP_lookup = leftjoin(RRAP_lookup, cots_priority, on=:GBRMPA_ID, order=:left)

# Cross-checking that the GBRMPA_ID from RRAP_lookup matches from cots_priority (within 500m - rounded values).
matching = DataFrame(match_lon=[], match_lat=[])
match_lon = (RRAP_lookup.cots_LON .< RRAP_lookup.LON .+ 0.005) .& (RRAP_lookup.cots_LON .> RRAP_lookup.LON .- 0.005)
match_lat = (RRAP_lookup.cots_LAT .< RRAP_lookup.LAT .+ 0.005) .& (RRAP_lookup.cots_LAT .> RRAP_lookup.LAT .- 0.005)
matching = DataFrame(match_lon=match_lon, match_lat=match_lat)
spat_mismatch = RRAP_lookup[(findall(skipmissing(.!matching.match_lon))),:] # With updated GBRMPA data all locations match

# Format output data.
RRAP_lookup = select!(RRAP_lookup, Not(:cots_LON, :cots_LAT))
rename!(RRAP_lookup, Dict(:priority=>:COTS_priority))
RRAP_lookup.COTS_priority .= ifelse.(ismissing.(RRAP_lookup.COTS_priority), "NA", RRAP_lookup.COTS_priority)
RRAP_lookup.COTS_priority .= ifelse.(RRAP_lookup.COTS_priority .== "Rank 1", "T", RRAP_lookup.COTS_priority)
RRAP_lookup.COTS_priority .= ifelse.(RRAP_lookup.COTS_priority .== "Rank 2", "P", RRAP_lookup.COTS_priority)
RRAP_lookup.COTS_priority .= ifelse.(RRAP_lookup.COTS_priority .== "Rank 3", "N", RRAP_lookup.COTS_priority)
RRAP_lookup.COTS_priority = convert.(String, RRAP_lookup.COTS_priority)

# Replace canonical file with updated data
GDF.write(canonical_file, RRAP_lookup; crs=GBRMPA_CRS)
