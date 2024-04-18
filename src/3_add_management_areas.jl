include("common.jl")

# GBRMPA management areas from https://geohub-gbrmpa.hub.arcgis.com/datasets/a21bbf8fa08346fabf825a849dfaf3b3_59/explore

# Load input data.
RRAP_lookup = GDF.read(joinpath(OUTPUT_DIR, find_latest_file(OUTPUT_DIR)))
management_areas = GDF.read(joinpath(DATA_DIR, "Great_Barrier_Reef_Marine_Park_Management_Areas_20_1685154518472315942.gpkg"))

# Find intersections and join to RRAP_lookout.
RRAP_management_areas = find_intersections(RRAP_lookup, management_areas, :GBRMPA_ID, :AREA_DESCR, :SHAPE)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_management_areas, on=:GBRMPA_ID, order=:left)

# Format data for output.
rename!(RRAP_lookup, Dict(:area_ID=>:management_area))
RRAP_lookup.management_area .= ifelse.(ismissing.(RRAP_lookup.management_area), "NA", RRAP_lookup.management_area)
RRAP_lookup.management_area = convert.(String, RRAP_lookup.management_area)

GDF.write(joinpath(OUTPUT_DIR, "rrap_shared_lookup_$(Dates.format(now(), "YYYY-mm-dd-THH-MM")).gpkg"), RRAP_lookup; crs=GFT.EPSG(4326))
