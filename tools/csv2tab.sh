#!/usr/bin/env bash

set -euo pipefail

column \
    -t \
    -s , \
    "${@}"
