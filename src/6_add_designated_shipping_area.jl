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

# Designated Shipping Area data from https://geohub-gbrmpa.hub.arcgis.com/datasets/19dffc7179f9469987f2dab6c1be77ad_74/explore?location=-17.228730%2C148.266261%2C5.82

# Load input data.
RRAP_lookup = GDF.read(joinpath(OUTPUT_DIR, find_latest_file(OUTPUT_DIR)))
shipping_areas = GDF.read(joinpath(DATA_DIR, "Great_Barrier_Reef_Marine_Park_Designated_Shipping_Areas_201_2053803872900928951.gpkg"))
shipping_areas[1,:NAME] = "Other GBR Areas" # renames the GBR area that is not shipping-exclusion to other gbr areas

# Find intersections and join to RRAP_lookup (use proportion = true to only assign a zone to a reef if the proportion of the selected zone covers > 50% of that reef).
RRAP_shipping = find_intersections(RRAP_lookup, shipping_areas, :GBRMPA_ID, :NAME, :SHAPE, proportion=true)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_shipping, on = :GBRMPA_ID, matchmissing = :notequal, order = :left)

# Format data for output.
rename!(RRAP_lookup, Dict(:area_ID => :designated_shipping_area))
RRAP_lookup.designated_shipping_area .= ifelse.(ismissing.(RRAP_lookup.designated_shipping_area), "NA", RRAP_lookup.designated_shipping_area)
RRAP_lookup.designated_shipping_area = convert.(String, RRAP_lookup.designated_shipping_area)

GDF.write(joinpath(OUTPUT_DIR, "rrap_shared_lookup_$(Dates.format(now(),"YYYY-mm-dd-THH-MM")).gpkg"), RRAP_lookup; crs=GFT.EPSG(4326))
