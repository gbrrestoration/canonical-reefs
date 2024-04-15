# Canonical Reefs

Attempt to create a standardized geopackage file including data from:

- `reefmod_gbr.gpkg` created from a combination of a shapefile found on Teams which provides
  the reef polygons and ReefMod id list CSV (see entry below).
  - This should be updated with a known canonical copy of the GBRMPA Reef Feature dataset
- A. Cresswell's Lookup table `GBR_reefs_lookup_table_Anna_update_2024-03-06.[csv/xlsx]`
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

There are several mismatches between the ReefMod reef list, AC lookup table and the GBRMPA
reef feature list (see details further below).

The entry for the GBRMPA Reef feature list (see link above) states that it has been updated
in 2023-08-16. Therefore, I assume those IDs are the most correct ones and default to those.

## Project Layout

Assumes `src` is the project root. Each file in `src` is expected to be run in order.

```code
GBR-FeatureAnalysis/
├─ src/          # Analysis
├─ data/         # data used to create canonical dataset
├─ output/       # results
├─ .gitignore
├─ Project.toml  # Julia project spec
├─ LICENSE.md
├─ README.md     # this file
```

## Setup

Usual Julia setup.

```bash
$ julia --project=.
```

```julia
# Instantiate project and switch to src directory
]instantiate
;cd src

# Run first script
include("1_create_canonical.jl")
```

## Discrepancies

Note that ReefMod Engine uses an older version of GBRMPA IDs (see notes in
`id_list_2023_03_30.csv` and below). I do not know which version is used more generally
across RRAP but I have made the decision to default to the updated GBRMPA IDs where there
are any discrepancies.

```code
    # Used in RME   Revised
    # 10-441        11-325
    # 11-288        11-244e
    # 11-303        11-244f
    # 11-310        11-244g
    # 11-311        11-244h
```

When comparing how many matching IDs are found in each dataset, they never align properly.

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

To resolve the above, I have:

1. Match reefs by their UNIQUE IDs between RME and GBRMPA datasets
2. Find the discrepancies between the two
3. Confirm the discrepancies between RME and GBRMPA datasets are the same as the ones
   reported above
4. Replace the older IDs with the new ones.
5. Copy the spatial geometries from the GBRMPA feature set
6. Reorder the dataframe based on the order given by AC lookup table (which should be
   identical to the RME features)
7. The AC lookup table and RME datasets ostensibly match by row order, so I copy columns
   of interest on that basis.

**In conversation with YM. Bozec, A. Cresswell, and M. Puotinen, there are several other
issues not yet accounted for (to be detailed once all info has been collated).**

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
