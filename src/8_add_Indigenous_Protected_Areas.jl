include("common.jl")

# Indigenous Protected Area data from https://fed.dcceew.gov.au/datasets/75c48afce3bb445f9ce58633467e21ed_0/explore

# Load input data.
RRAP_lookup = GDF.read(joinpath(OUTPUT_DIR, find_latest_file(OUTPUT_DIR)))
IPA_zones = GDF.read(joinpath(DATA_DIR, "Indigenous_Protected_Areas_-_Dedicated.geojson"))

# Find intersections and join to RRAP_lookup.
RRAP_IPA_zones = find_intersections(RRAP_lookup, IPA_zones, :GBRMPA_ID, :NAME, :geometry)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_IPA_zones, on=:GBRMPA_ID, matchmissing=:notequal, order=:left)

# Format for data output.
rename!(RRAP_lookup, Dict(:area_ID=>:Indigenous_Protected_Area))
RRAP_lookup.Indigenous_Protected_Area .= ifelse.(ismissing.(RRAP_lookup.Indigenous_Protected_Area), "NA", RRAP_lookup.Indigenous_Protected_Area)
RRAP_lookup.Indigenous_Protected_Area = convert.(String, RRAP_lookup.Indigenous_Protected_Area)

GDF.write(joinpath(OUTPUT_DIR, "rrap_shared_lookup_$(Dates.format(now(), "YYYY-mm-dd-THH-MM")).gpkg"), RRAP_lookup; crs=GFT.EPSG(4326))
