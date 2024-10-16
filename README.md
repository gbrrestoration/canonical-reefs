# Canonical Reefs

Generates a standardized geopackage file including data from:

- Dr A. Cresswell's Lookup table `GBR_reefs_lookup_table_Anna_update_2024-03-06.[csv/xlsx]`
  This is referred to as the AC lookup table.
- `id_list_2023_03_30.csv` from ReefMod Engine 2024-01-08 (v1.0.28)
- GBRMPA Reef Feature dataset:
  - https://data.gov.au/dataset/ds-dga-51199513-98fa-46e6-b766-8e1e1c896869/details
  - The metadata for the data.gov.au entry states it has been "Updated 16/08/2023"
- GBRMPA regional management areas:
  - https://geohub-gbrmpa.hub.arcgis.com/datasets/a21bbf8fa08346fabf825a849dfaf3b3_59/explore
- GBRMPA marine park zones:
  - https://geohub-gbrmpa.hub.arcgis.com/datasets/6dd0008183cc49c490f423e1b7e3ef5d_53/explore
- Traditional Use of Marine Resource Agreements:
  - https://geohub-gbrmpa.hub.arcgis.com/datasets/ef9027e13fd043c6b8aeda8faf756a86_55/explore?location=-17.864328%2C148.056236%2C5.81
- Designated Shipping Areas:
  - https://geohub-gbrmpa.hub.arcgis.com/datasets/19dffc7179f9469987f2dab6c1be77ad_74/explore
- Cruise Ship Transit Lanes:
  - https://geohub-gbrmpa.hub.arcgis.com/datasets/5a93ef2976ce4c589c55098b329f012f_61/explore?location=-16.689409%2C146.920083%2C6.33
- Indigenous Protected Areas:
  - https://fed.dcceew.gov.au/datasets/75c48afce3bb445f9ce58633467e21ed_0/explore
- Indigenous Land Use Agreements:
  - http://www.nntt.gov.au/assistance/Geospatial/Pages/DataDownload.aspx
- Satellite-derived Bathymetry data at 10m resolution
  - https://gbrmpa.maps.arcgis.com/home/item.html?id=f644f02ec646496eb5d31ad4f9d0fc64
  - Functionality of depth extraction (Script `10_extract_reef_depths.jl`) relies on depth
  data being in a projection with metre coordinate units.
- QLD Port Location data
  - Provided by Dr. Marji Puotinen
- EcoRRAP site locations from EcoRRAP team
  - Provided by Dr. Maren Toor

There are several mismatches between the ReefMod reef list, AC lookup table and the GBRMPA
reef feature list (see details further below).

The entry for the GBRMPA Reef feature list (see link above) states that it has been updated
in 2023-08-16. Therefore, it is assumed these IDs are the most recent and up to date, and
are used as the default if any issues arise.

## Project Layout

Assumes `src` is the project root. Each file in `src` is expected to be run in order.

```code
GBR-FeatureAnalysis/
├─ src/          # Analysis
├─ data/         # Data used to create canonical dataset
├─ output/       # Results
├─ .gitignore
├─ Project.toml  # Julia project spec
├─ LICENSE.md
├─ README.md     # this file
```

## Setup

The location of project-specific datasets, specifically, the bathymetry data, needs to be
defined by creating a `.config.toml` file inside the `src` directory. The options set in
this file is unique to each user, and should not be committed to the repository.

```TOML
[bathy]
BATHY_DATA_DIR = "path to bathymetry data"  # location of bathymetry raster datasets
```

Otherwise, follow the usual Julia setup process.

```bash
$ julia --project=.
```

```julia
# Instantiate project and switch to src directory
]instantiate
;cd src
```

```julia
# Run first script
include("1_create_canonical.jl")

# Run all scripts
include("run_all.jl")
```

The final outputted file is a geopackage of the form:
`canonical_gbr_[date scripts were run].gpkg`.

## Discrepancies

Note that ReefMod Engine uses an older version of GBRMPA IDs (see notes in
`id_list_2023_03_30.csv` and below).

The most recent GBRMPA IDs are used by default where any discrepancies are encountered.

```code
    # Used in RME   Revised
    # 10-441        11-325
    # 11-288        11-244e
    # 11-303        11-244f
    # 11-310        11-244g
    # 11-311        11-244h
```

Note that no list of IDs from the datasets described above completely align:

```julia
# Expected 100% match is 3806 (the number of reefs represented in ReefMod)

# AC Lookup compared to GBR feature list
count(ac_lookup.UNIQUE_ID .∈ [gbr_features.UNIQUE_ID])
# 3794

# RME reef list compared to GBR feature list
count(rme_features.UNIQUE_ID .∈ [gbr_features.UNIQUE_ID])
# 3801 (could be explained by the above revised IDs)

# AC lookup compared to RME reef list
count(ac_lookup.UNIQUE_ID .∈ [rme_features.UNIQUE_ID])
# 3799
```

## Resolving discrepancies

To resolve the above:

1. Reefs are matched by their UNIQUE IDs between RME and GBRMPA datasets
2. Determine the discrepancies between the two
3. Confirm the discrepancies between RME and GBRMPA datasets are the same as the ones
   reported above
4. Replace the older IDs with the new updated IDs.
5. Copy the spatial geometries from the GBRMPA feature set
6. Reorder the dataframe based on the order given by AC lookup table (which are
   identical to the RME features)
7. The AC lookup table and RME datasets ostensibly match by row order, columns of interest
   are copied on that basis.

**In conversation with YM. Bozec, A. Cresswell, and M. Puotinen, there are several other
issues yet to be accounted for (to be detailed once all info has been collated).**

## Relevant details

The geopackage compiled at the end should then have the correct reef names, IDs, and
locations/geometries.

```julia
# Find UNIQUE IDs in RME dataset that do not appear in GBRMPA dataset
julia> mismatched_unique = findall(.!(rme_features.UNIQUE_ID .∈ [gbr_features.UNIQUE_ID]))
# 5-element Vector{Int64}:
#  103
#  451
#  466
#  473
#  474

 # IDs of the mismatched reefs
julia> rme_features.UNIQUE_ID[mismatched_unique]
# 5-element Vector{String}:
#  "10441100104"
#  "11288100104"
#  "11303100104"
#  "11310100104"
#  "11311100104"

# These missing ones are the same as noted above by their LTMP IDs
# So we replace these with the revised IDs
julia> rme_features[mismatched_unique, :LABEL_ID]
# 5-element Vector{String}:
# "10-441"
# "11-288"
# "11-303"
# "11-310"
# "11-311"
```

## Adding Additional Data

The following scripts add data to the initial .gpkg created by `1_create_canonical.jl`.
The setup script (`1_create_canonical.jl`) must be run before the following scripts.
These scripts make use of the `find_intersections()` function defined in `common.jl`.
Each script saves to the same file: `rrap_canonical_[date of creation].gpkg`

- `2_add_cots_priority.jl` : Adds the priority level for cots intervention for each reef.
- `3_add_management_areas.jl` : Adds the corresponding regional management areas as used by GBRMPA for each reef.
- `4_add_GBRMPA_zones.jl` : Adds the corresponding marine park zoning for each reef.
- `5_add_Traditional_Use_of_Marine_Resources_Agreements.jl` : Adds Traditional Use of Marine Resource Agreement labels where applicable to each reef.
- `6_add_designated_shipping_areas.jl` : Adds the corresponding Shipping Exclusion Areas to each reef where applicable.
- `7_add_cruise_transit_lanes.jl` : Adds the corresponding Cruise Ship Transit Lane label to each reef where applicable.
- `8_add_Indigenous_Protected_Areas.jl` : Adds the corresponding Indigenous Protected Areas to reefs where applicable.
- `9_add_Indigenous_Land_Use_Agreements.jl` : Adds the corresponding Indigenous Land Use Agreement area labels to each reef where applicable.
- `10_extract_reef_depths.jl` : Use reef features to estimate reef depths from satellite-derived raster data.
- `11_distance_nearest_port.jl` : Find the port closest to a reef. Document port name and corresponding distance (in meters using Haversine distance).
- `12_update_EcoRRAP_locations.jl` : Update reefs that contain EcoRRAP sites to reflect current site list.

## Notes on feature attributes

### UNIQUE IDs

There needs to be a unique identifier so that all models can link their conceptualizations
of a "reef" back to a common dataset. In Relational Databases this is known as a
"Primary Key". Reef names should not be relied on as there are many "reefs" with
(near-)identical or duplicate names. For example, 57.2% of reefs share the name "U/N Reef".

Unfortunately, due to slight changes over time including updated processing workflows,
revisions by external orgs, and/or changes to definitions of what a "reef" is, the assigned
`UNIQUE_ID` no longer match.

To allow cross-comparison and validation, the following IDs are included:

- `UNIQUE_ID` : From the most recent GBRMPA reef feature dataset
- `RME_UNIQUE_ID` : Taken from the most recent ReefMod Engine reef list file
- `GBRMPA_ID` : An alternate reef id list maintained by GBRMPA (e.g., "10-330", ""10-318a")
- `RME_GBRMPA_ID` : As above, but as defined by the ReefMod Engine reef list file
- `LTMP_ID` : A seven character ID largely following the `GBRMPA_ID` format maintained by AIMS for the Long-Term Monitoring Program
- `LON` and `LAT` : Pre-determined longitude and latitudes from GBRMPA reef feature set
- `reef_name` : Name of reef (with GBRMPA_ID included in parenthesis)

Additionally, **all attribute names are standardized to follow `snake_case` formatting**, except
in cases where:

- Pre-existing naming convention (e.g., `UNIQUE_ID`)
- An established acronym exists (e.g., `TUMRA`, `GBRMPA`, `LTMP`, etc.)

### COTS Priority reefs

Paraphrasing details from Dr S. Condie (pers comm. Thu 2024-03-28 14:23).

GBRMPA classifies reefs as:

- T = target
- P = priority
- N = non-priority

In both CoCoNet and ReefMod, reefs are controlled until annual capacity (based on number of
vessels and divers) is fully utilised, starting by selecting randomly from the target reefs,
then randomly from the priority reefs, and then - if there is spare capacity, which is
rarely - randomly from the non-priority.

### Depth Data and Quality Control flags

Raw GBRMPA bathymetry data contains positive values for locations above sea level, and
negative values for below sea level. In depth statistic calculation for canonical-reefs
output this has been reversed as ADRIA expects depth values below sea level to be positive.

Slight mismatches exist between GBRMPA bathymetry data and the reef features.

The `depth_qc` attribute values indicate:

- 0 : no error (does not indicate polygons that only partially overlapped a given reef!)
- 1 : flags that the reef feature did not overlap any satellite data (value set to 7m)
- 2 : flags that the minimum value was above sea level (no changes/adjustments made)
- 3 : flags that depth raster data used for statistic calculation covers less than
5% of the polygon reef area

### Coordinate Reference Systems

`1_create_canonical.jl` uses a Great Barrier Reef Features dataset to create the initial
canoical dataset. These features are in CRS EPSG:4283 (GDA1994). These features are then
reprojected to be in CRS EPSG:7844 (GDA2020) to be consistent with other data from GBRMPA.

### Possible error in reef features

The polygon with reef_name U/N Reef (20-553) has a possible error in the original data that
results in the reef being a small polygon located on the edge of Rip Reef (20-0370a).

## Incorrect GBRMPA_ID Identifier
GBRMPA datsets using GBRMPA_ID (e.g. 20-553) contain an incorrect ID where identifier "20198"
is missing a hyphen (correct ID: "20-198"). This mistake has been preserved in the output
geopackage GBRMPA_ID column to match current GBRMPA data (we include this
ID as "20198"). Other data sources using GBMPRA_ID may have fixed this identifier.

RME_GBRMPA_ID column contains this ID as "20-198" rather than "20198" as this matches the
latest reef_id set provided by the ReefMod team.