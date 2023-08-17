#!/usr/bin/env bash

set -euo pipefail

column \
    -t \
    -N 'IO,Case,Throughput (B/s),Throughput (MB/s)' \
    -H 3 \
    -s , \
    "${@}"
