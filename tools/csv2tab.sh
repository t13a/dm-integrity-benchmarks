#!/usr/bin/env bash

set -euo pipefail

column \
    -t \
    -N 'Access,Case,Throughput (B/s),Throughput (MiB/s)' \
    -H 3 \
    -s , \
    "${@}"
