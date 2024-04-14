using
    CSV,
    Dates,
    DataFrames

using
    GLMakie,
    GeoMakie

using
    Statistics,
    Bootstrap

import GeoDataFrames as GDF
import GeoFormatTypes as GFT
import ArchGDAL as AG

include("common.jl")


#load input data
RRAP_lookup = GDF.read(joinpath(OUTPUT_DIR, "rrap_shared_lookup.gpkg"))
GBRMPA_zones = GDF.read(joinpath(DATA_DIR, "Great_Barrier_Reef_Marine_Park_Zoning_20_4418126048110066699.gpkg"))
unique_zones = unique(GBRMPA_zones[:,[:TYPE,:ALT_ZONE]])

#find and join matching zones for each RRAP lookup reef
RRAP_GBRMPA_zones = find_intersections(RRAP_lookup, GBRMPA_zones, :GBRMPA_ID, :TYPE, :SHAPE)
rename!(RRAP_GBRMPA_zones, Dict(:area_ID => :TYPE))
RRAP_GBRMPA_zones = leftjoin(RRAP_GBRMPA_zones, unique_zones[:,[:TYPE,:ALT_ZONE]], on = :TYPE, matchmissing = :notequal)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_GBRMPA_zones, on = :GBRMPA_ID, order = :left)

#format data for output
rename(RRAP_lookup, Dict(:TYPE => :GBRMPA_zones, :ALT_ZONE => :zone_colour))
RRAP_lookup.GBRMPA_zones .= ifelse.(ismissing.(RRAP_lookup.GBRMPA_zones), "NA", RRAP_lookup.GBRMPA_zones)
RRAP_lookup.GBRMPA_zones = convert.(String, RRAP_lookup.GBRMPA_zones)
RRAP_lookup.zone_colour .= ifelse.(ismissing.(RRAP_lookup.zone_colour), "NA", RRAP_lookup.zone_colour)
RRAP_lookup.zone_colour = convert.(String, RRAP_lookup.zone_colour)

GDF.write(joinpath(OUTPUT_DIR, "rrap_shared_lookup.gpkg"), RRAP_lookup; crs=GFT.EPSG(4326))
