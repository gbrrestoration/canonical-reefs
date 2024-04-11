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
management_areas = GDF.read(joinpath(DATA_DIR, "Great_Barrier_Reef_Marine_Park_Management_Areas_20_1685154518472315942.gpkg"))

#find intersections and join to RRAP_lookout
RRAP_management_areas = find_intersections(RRAP_lookup, management_areas, :GBRMPA_ID, :AREA_DESCR, :SHAPE)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_management_areas, on = :GBRMPA_ID)

#format data for output
rename!(RRAP_lookup, Dict(:area_ID => :management_area))
RRAP_lookup.management_area .= ifelse.(ismissing.(RRAP_lookup.management_area), "NA", RRAP_lookup.management_area)
RRAP_lookup.management_area = convert.(String, RRAP_lookup.management_area)

GDF.write(joinpath(OUTPUT_DIR, "rrap_shared_lookup.gpkg"), RRAP_lookup; crs=GFT.EPSG(4326))
