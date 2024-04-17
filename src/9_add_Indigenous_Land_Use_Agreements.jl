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

using GeoIO
import GeoDataFrames as GDF
import GeoFormatTypes as GFT
import ArchGDAL as AG

include("common.jl")

# Indigenous Land Use Agreement data from http://www.nntt.gov.au/assistance/Geospatial/Pages/DataDownload.aspx

# Reformat ILUA shapefile to geojson for loading with GeoDataFrames - can't load original with GDF.load() due to date formats in shp
ILUA_geotable_init = GeoIO.load(joinpath(DATA_DIR, "indigenous_land_use_agreements/ILUA_Registered_Notified_Nat.shp"))
GeoIO.save(joinpath(DATA_DIR,"Indigenous_Land_Use_Agreements.geojson"), ILUA_geotable_init)

# Load input data.
RRAP_lookup = GDF.read(joinpath(OUTPUT_DIR, find_latest_file(OUTPUT_DIR)))
ILUA_zones = GDF.read(joinpath(DATA_DIR, "Indigenous_Land_Use_Agreements.geojson"))

# Find intersections and join to RRAP_lookup.
RRAP_ILUA_zones = find_intersections(RRAP_lookup, ILUA_zones, :GBRMPA_ID, :NAME, :geometry)
RRAP_lookup = leftjoin(RRAP_lookup, RRAP_ILUA_zones, on=:GBRMPA_ID, matchmissing=:notequal, order=:left)

# Format data for output.
rename!(RRAP_lookup, Dict(:area_ID => :Indigenous_Land_Use_Agreement))
RRAP_lookup.Indigenous_Land_Use_Agreement .= ifelse.(ismissing.(RRAP_lookup.Indigenous_Land_Use_Agreement), "NA", RRAP_lookup.Indigenous_Land_Use_Agreement)
RRAP_lookup.Indigenous_Land_Use_Agreement = convert.(String, RRAP_lookup.Indigenous_Land_Use_Agreement)

GDF.write(joinpath(OUTPUT_DIR, "rrap_shared_lookup_$(Dates.format(now(),"YYYY-mm-dd-THH-MM")).gpkg"), RRAP_lookup; crs=GFT.EPSG(4326))
