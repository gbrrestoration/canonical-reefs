#!/bin/bash

cd src
julia --project=.. -e 'include("1_create_canonical.jl")'  && julia --project=.. -e 'include("run_all.jl")'
