"""
Write additional file formats last.
"""

GDF.write(replace(canonical_file, ".gpkg" => ".geojson"), RRAP_lookup; crs=GBRMPA_CRS)
CSV.write(replace(canonical_file, ".gpkg" => ".csv"), RRAP_lookup[:, Not(:geometry)])
