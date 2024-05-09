include("common.jl")

Ports = GDF.read("c:/Users/bgrier/Documents/QLD_ports_mercator_via_MP/ports_QLD_merc.shp")
canonical_file = find_latest_file(OUTPUT_DIR)
RRAP_lookup = GDF.read(canonical_file)

Ports.geometry = AG.reproject(Ports.geometry, crs(Ports[1,:geometry]), crs(RRAP_lookup[1,:geometry]); order=:trad)

RRAP_lookup[:,:closest_port] .= ""
RRAP_lookup[:,:min_port_distance] .= 0.0

#returns the closest port (in degrees - not using haversine)
for reef in eachrow(RRAP_lookup)
    distances = AG.distance.([reef.geometry], Ports.geometry)
    closest_port = Ports[argmin(distances),:Name]
    min_dist = distances[argmin(distances)]
    reef[:closest_port] = closest_port
    reef[:min_port_distance] = min_dist
end

#trying to calculate the distance between each point in a polygon and a port (can just be used to calculate that for the closes port to each reef after last step^)
port = (AG.getx(Ports[1,:geometry],0), AG.gety(Ports[1,:geometry],0))
reef1 = AG.getgeom(RRAP_lookup[1,:geometry],0) #AG.getgeom and getx/y use 0 as the first index!
reef_point = (AG.getx(reef1,0), AG.gety(reef1,0))
haversine(port, reef_point) # this works but I don't know how to see how many points are inside reef1 to index them all (0-x)


Distances.haversine(Ports[1,:geometry],RRAP_lookup[1,:geometry])
