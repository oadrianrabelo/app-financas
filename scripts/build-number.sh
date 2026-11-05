#!/usr/bin/env bash
# Número de build (versionCode do Android) a partir da versão: 1.2.3 -> 1002003.
# Sempre cresce junto com a versão, então o Android aceita a atualização.
set -euo pipefail
IFS=. read -r major minor patch <<< "${1%%-*}"
echo $(( major * 1000000 + minor * 1000 + patch ))
