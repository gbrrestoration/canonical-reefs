using XLSX

include("common.jl")

canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)

ecorrap_sites = GDF.read(joinpath(DATA_DIR, "ecorrap_zone_locations.gpkg"))
ecorrap_sites.geom  = AG.reproject(ecorrap_sites.geom, crs(ecorrap_sites[1, :geom]), crs(RRAP_lookup[1, :geometry]); order=:trad)

site_name_path = joinpath(DATA_DIR, "EcoRRAP Zones_Master.xlsx")
site_names = DataFrame(XLSX.readtable(site_name_path, "EcoRRAP Zone Naming"))
rename!(site_names, "Full code_Master" => :old_site_name)

ecorrap_reefs = []
for reef in eachrow(RRAP_lookup.geometry)
    sites = ecorrap_sites[AG.intersects.(reef, ecorrap_sites.geom), :]

    if !isempty(sites)
        site_cluster = site_names[(site_names.old_site_name .== sites[1,:Name]), :].Cluster_New[1]
        push!(ecorrap_reefs, site_cluster)
    else
        push!(ecorrap_reefs, missing)
    end
end

RRAP_lookup.EcoRRAP_photogrammetry_reef = ecorrap_reefs
RRAP_lookup.EcoRRAP_photogrammetry_reef .= ifelse.(ismissing.(RRAP_lookup.EcoRRAP_photogrammetry_reef), "NA", RRAP_lookup.EcoRRAP_photogrammetry_reef)
RRAP_lookup.EcoRRAP_photogrammetry_reef = convert.(String, RRAP_lookup.EcoRRAP_photogrammetry_reef)

GDF.write(canonical_file, RRAP_lookup; crs=GBRMPA_CRS)
GDF.write(replace(canonical_file, ".gpkg"=>".geojson"), RRAP_lookup)
CSV.write(replace(canonical_file, ".gpkg"=>".csv"), RRAP_lookup[:, Not(:geometry)])
