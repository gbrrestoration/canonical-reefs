include("common.jl")

# Indigenous Land Use Agreement data from http://www.nntt.gov.au/assistance/Geospatial/Pages/DataDownload.aspx

# Load input data.
canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)
ILUA_zones = GDF.read(joinpath(DATA_DIR, "indigenous_land_use_agreements/ILUA_Registered_Notified_Nat.shp"))

# Reproject indigenous land use agreement zones to EPSG:7844 (GDA2020) to match RRAP_lookup
ILUA_zones.geometry = AG.reproject(ILUA_zones.geometry, GI.crs(ILUA_zones[1,:geometry]), EPSG(7844); order=:trad)

# Find intersections and join to RRAP_lookup.
RRAP_ILUA_zones = find_intersections(RRAP_lookup, ILUA_zones, :GBRMPA_ID, :NAME, :geometry)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_ILUA_zones, on=:GBRMPA_ID, matchmissing=:notequal, order=:left)

# Format data for output.
rename!(RRAP_lookup, Dict(:area_ID=>:Indigenous_Land_Use_Agreement))
RRAP_lookup.Indigenous_Land_Use_Agreement .= ifelse.(ismissing.(RRAP_lookup.Indigenous_Land_Use_Agreement), "NA", RRAP_lookup.Indigenous_Land_Use_Agreement)
RRAP_lookup.Indigenous_Land_Use_Agreement = convert.(String, RRAP_lookup.Indigenous_Land_Use_Agreement)

GDF.write(canonical_file, RRAP_lookup; crs=GBRMPA_CRS)
