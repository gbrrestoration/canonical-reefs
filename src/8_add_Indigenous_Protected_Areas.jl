include("common.jl")

# Indigenous Protected Area data from https://fed.dcceew.gov.au/datasets/75c48afce3bb445f9ce58633467e21ed_0/explore

# Load input data.
canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)
IPA_zones = GDF.read(joinpath(DATA_DIR, "Indigenous_Protected_Areas_-_Dedicated.geojson"))

# Find intersections and join to RRAP_lookup.
RRAP_IPA_zones = find_intersections(RRAP_lookup, IPA_zones, :GBRMPA_ID, :NAME, :geometry)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_IPA_zones, on=:GBRMPA_ID, matchmissing=:notequal, order=:left)

# Format for data output.
rename!(RRAP_lookup, Dict(:area_ID=>:indigenous_protected_area))
RRAP_lookup.indigenous_protected_area .= ifelse.(ismissing.(RRAP_lookup.indigenous_protected_area), "NA", RRAP_lookup.indigenous_protected_area)
RRAP_lookup.indigenous_protected_area = convert.(String, RRAP_lookup.indigenous_protected_area)

GDF.write(canonical_file, RRAP_lookup; crs=GFT.EPSG(4326))
