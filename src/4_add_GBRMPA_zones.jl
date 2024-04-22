include("common.jl")

# GBRMPA Marine Park Zoning data from https://geohub-gbrmpa.hub.arcgis.com/datasets/6dd0008183cc49c490f423e1b7e3ef5d_53/explore

# Load input data.
RRAP_lookup = GDF.read(joinpath(OUTPUT_DIR, find_latest_file(OUTPUT_DIR)))
GBRMPA_zones = GDF.read(joinpath(DATA_DIR, "Great_Barrier_Reef_Marine_Park_Zoning_20_4418126048110066699.gpkg"))
unique_zones = unique(GBRMPA_zones[:, [:TYPE, :ALT_ZONE]])

# Find and join matching zones for each RRAP lookup reef.
RRAP_GBRMPA_zones = find_intersections(RRAP_lookup, GBRMPA_zones, :GBRMPA_ID, :TYPE, :SHAPE)
rename!(RRAP_GBRMPA_zones, Dict(:area_ID=>:TYPE))
RRAP_GBRMPA_zones = leftjoin(RRAP_GBRMPA_zones, unique_zones[:, [:TYPE, :ALT_ZONE]], on=:TYPE, matchmissing=:notequal)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_GBRMPA_zones, on=:GBRMPA_ID, order=:left)

# Format data for output.
rename!(RRAP_lookup, Dict(:TYPE=>:GBRMPA_zones, :ALT_ZONE=>:zone_colour))
RRAP_lookup.GBRMPA_zones .= ifelse.(ismissing.(RRAP_lookup.GBRMPA_zones), "NA", RRAP_lookup.GBRMPA_zones)
RRAP_lookup.GBRMPA_zones = convert.(String, RRAP_lookup.GBRMPA_zones)
RRAP_lookup.zone_colour .= ifelse.(ismissing.(RRAP_lookup.zone_colour), "NA", RRAP_lookup.zone_colour)
RRAP_lookup.zone_colour = convert.(String, RRAP_lookup.zone_colour)

GDF.write(joinpath(OUTPUT_DIR, "rrap_shared_lookup_$(Dates.format(now(), DATE_FORMAT)).gpkg"), RRAP_lookup; crs=GFT.EPSG(4326))
