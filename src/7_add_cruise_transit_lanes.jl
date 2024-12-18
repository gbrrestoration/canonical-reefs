include("common.jl")

#Cruise ship transit lane data from https://geohub-gbrmpa.hub.arcgis.com/datasets/5a93ef2976ce4c589c55098b329f012f_61/explore

# Load input data.
canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)
cruise_transit = GDF.read(joinpath(DATA_DIR, "Great_Barrier_Reef_Marine_Park_Cruise_Ship_Transit_Lanes_20_-6667226202001620759.gpkg"))

# Find intersections and join to RRAP_lookup (use proportion = true to only assign a zone to a reef if the proportion of the selected zone covers > 50% of that reef).
RRAP_cruise_transit = find_intersections(RRAP_lookup, cruise_transit, :GBRMPA_ID, :AREA_DESCR, :SHAPE, proportion=true)
rename!(RRAP_cruise_transit, Dict(:area_ID=>:AREA_DESCR))
RRAP_cruise_transit = leftjoin(RRAP_cruise_transit, cruise_transit[:, [:AREA_DESCR, :NOTES]],on=:AREA_DESCR, matchmissing=:notequal, order=:left)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_cruise_transit, on=:GBRMPA_ID, matchmissing=:notequal, order=:left)

# Format data for output
rename!(RRAP_lookup, Dict(:AREA_DESCR=>:cruise_transit_lane, :NOTES=>:cruise_transit_notes))
RRAP_lookup.cruise_transit_lane .= ifelse.(ismissing.(RRAP_lookup.cruise_transit_lane), "NA", RRAP_lookup.cruise_transit_lane)
RRAP_lookup.cruise_transit_lane = convert.(String, RRAP_lookup.cruise_transit_lane)
RRAP_lookup.cruise_transit_notes .= ifelse.(ismissing.(RRAP_lookup.cruise_transit_notes), "NA", RRAP_lookup.cruise_transit_notes)
RRAP_lookup.cruise_transit_notes = convert.(String, RRAP_lookup.cruise_transit_notes)

GDF.write(canonical_file, RRAP_lookup; crs=GBRMPA_CRS)
