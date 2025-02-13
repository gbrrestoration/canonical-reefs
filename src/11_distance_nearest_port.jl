using Distances

include("common.jl")

Ports = GDF.read(joinpath(DATA_DIR, "QLD_ports_mercator_via_MP/ports_QLD_merc.shp"))
canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)

Ports.geometry = AG.reproject(Ports.geometry, crs(Ports[1, :geometry]), crs(RRAP_lookup[1, :geometry]); order=:trad)

RRAP_lookup[:, :closest_port] .= ""
RRAP_lookup[:, :min_port_distance] .= 0.0

#returns the closest port and the distance - in meters (using Haversine distance)
for reef in eachrow(RRAP_lookup)
    distances = AG.distance.([reef.geometry], Ports.geometry)
    closest_port, port_point = Ports[argmin(distances), [:Name, :geometry]]

    port_point = (AG.getx(port_point, 0), AG.gety(port_point, 0))
    reef_center = AG.centroid(reef.geometry)
    reef_center = (AG.getx(reef_center, 0), AG.gety(reef_center, 0))
    min_dist = Distances.haversine(port_point, reef_center)

    reef[:closest_port] = closest_port
    reef[:min_port_distance] = min_dist
end

GDF.write(canonical_file, RRAP_lookup; crs=GBRMPA_CRS)
