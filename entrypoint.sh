#!/bin/bash

cd src
julia --project=.. -e 'include("run_all.jl")'
