include("common.jl")

# Load required data.
canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)
cots_target = CSV.read(joinpath(DATA_DIR, "COTS_Target_Reefs_Cull_Data_2024_25.csv"), DataFrame)

# Format input data.
rename!(
    cots_target,
    Dict(
        "Latitude"=>:cots_LAT,
        "Longitude"=>:cots_LON,
        "ReefID"=>:GBRMPA_ID,
        #"RankForAction"=>:target
        )
    )
cots_target = cots_target[:, [:GBRMPA_ID, :cots_LON, :cots_LAT]]
# Add a column called `target` with value "T" for each row as the table provided is just of Target Reefs
insertcols!(cots_target, :target => "T")

# Adding cots target into RRAP_lookup.
RRAP_lookup = leftjoin(RRAP_lookup, cots_target, on=:GBRMPA_ID, order=:left)

# Cross-checking that the GBRMPA_ID from RRAP_lookup matches from cots_target (within 500m - rounded values).
matching = DataFrame(match_lon=[], match_lat=[])
match_lon = (RRAP_lookup.cots_LON .< RRAP_lookup.LON .+ 0.005) .& (RRAP_lookup.cots_LON .> RRAP_lookup.LON .- 0.005)
match_lat = (RRAP_lookup.cots_LAT .< RRAP_lookup.LAT .+ 0.005) .& (RRAP_lookup.cots_LAT .> RRAP_lookup.LAT .- 0.005)
matching = DataFrame(match_lon=match_lon, match_lat=match_lat)
spat_mismatch = RRAP_lookup[(findall(skipmissing(.!matching.match_lon))),:] # With updated GBRMPA data all locations match

# Format output data.
RRAP_lookup = select!(RRAP_lookup, Not(:cots_LON, :cots_LAT))
rename!(RRAP_lookup, Dict(:target=>:COTS_target))
RRAP_lookup.COTS_target .= ifelse.(ismissing.(RRAP_lookup.COTS_target), "NA", RRAP_lookup.COTS_target)

RRAP_lookup.COTS_target = convert.(String, RRAP_lookup.COTS_target)

# Replace canonical file with updated data
GDF.write(canonical_file, RRAP_lookup; crs=GBRMPA_CRS)
