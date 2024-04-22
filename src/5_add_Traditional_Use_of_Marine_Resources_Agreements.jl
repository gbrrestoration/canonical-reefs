include("common.jl")

# Traditional Use of Marine Resources data from https://geohub-gbrmpa.hub.arcgis.com/datasets/ef9027e13fd043c6b8aeda8faf756a86_55/explore?location=-17.864328%2C148.056236%2C5.81

# Load input data.
RRAP_lookup = GDF.read(joinpath(OUTPUT_DIR, find_latest_file(OUTPUT_DIR)))
TUMRA_zones = GDF.read(joinpath(DATA_DIR, "Great_Barrier_Reef_Marine_Park_Traditional_Use_of_Marine_Resources_TUMRA_20_-7457312266299026706.gpkg"))
TUMRA_unique = unique(TUMRA_zones[:, [:NAME, :Entity]])

# Find intersections and join columns to RRAP_lookup.
RRAP_TUMRA_zones = find_intersections(RRAP_lookup, TUMRA_zones, :GBRMPA_ID, :NAME, :SHAPE)
rename!(RRAP_TUMRA_zones, Dict(:area_ID=>:NAME))
RRAP_TUMRA_zones = leftjoin(RRAP_TUMRA_zones, TUMRA_unique[:, [:NAME, :Entity]], on=:NAME, matchmissing=:notequal)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_TUMRA_zones, on=:GBRMPA_ID, matchmissing=:notequal, order=:left)

# Format data for output.
rename!(RRAP_lookup, Dict(:NAME=>:TUMRA_name, :Entity=>:TUMRA_entity))
RRAP_lookup.TUMRA_name .= ifelse.(ismissing.(RRAP_lookup.TUMRA_name), "NA", RRAP_lookup.TUMRA_name)
RRAP_lookup.TUMRA_name = convert.(String, RRAP_lookup.TUMRA_name)
RRAP_lookup.TUMRA_entity .= ifelse.(ismissing.(RRAP_lookup.TUMRA_entity), "NA", RRAP_lookup.TUMRA_entity)
RRAP_lookup.TUMRA_entity = convert.(String, RRAP_lookup.TUMRA_entity)

GDF.write(joinpath(OUTPUT_DIR, "rrap_shared_lookup_$(Dates.format(now(), DATE_FORMAT)).gpkg"), RRAP_lookup; crs=GFT.EPSG(4326))
