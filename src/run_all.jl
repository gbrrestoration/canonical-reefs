"""
Run all steps to create the canonical reef features dataset.

Documented details found in the README and individual scripts.
"""

include("01_create_canonical.jl");
include("02_add_cots_priority.jl");
include("03_add_management_areas.jl");
include("04_add_GBRMPA_zones.jl");
include("05_add_Traditional_Use_of_Marine_Resources_Agreements.jl");
include("06_add_designated_shipping_area.jl");
include("07_add_cruise_transit_lanes.jl");
include("08_add_Indigenous_Protected_Areas.jl");
include("09_add_Indigenous_Land_Use_Agreements.jl");
include("10_extract_reef_depths.jl");
include("11_distance_nearest_port.jl");
include("12_update_EcoRRAP_locations.jl");
include("13_add_GBRMPA_bioregions.jl")
include("14_add_cb_calib_groups.jl")

include("write_results.jl")
