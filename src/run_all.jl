"""
Run all steps to create the canonical reef features dataset.

Documented details found in the README and individual scripts.
"""

include("1_create_canonical.jl");
include("2_add_cots_priority.jl");
include("3_add_management_areas.jl");
include("4_add_GBRMPA_zones.jl");
include("5_add_Traditional_Use_of_Marine_Resources_Agreements.jl");
include("6_add_designated_shipping_area.jl");
include("7_add_cruise_transit_lanes.jl");
include("8_add_Indigenous_Protected_Areas.jl");
include("9_add_Indigenous_Land_Use_Agreements.jl");
include("10_extract_reef_depths.jl");
include("11_distance_nearest_port.jl");
include("12_update_EcoRRAP_locations.jl");
include("13_add_GBRMPA_bioregions.jl")
include("14_add_spatial_groupings.jl")

include("write_results.jl")
