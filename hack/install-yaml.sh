#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

mkdir -p release/

# Make clean files with boilerplate
cat << EOF >> release/install.yaml
#
# Gateway Config Injector install
#
EOF

for file in `ls config/*.yaml`
do
    echo "---" >> release/install.yaml
    echo "#" >> release/install.yaml
    echo "# $file" >> release/install.yaml
    echo "#" >> release/install.yaml
    cat $file >> release/install.yaml
done

echo "Generated:" release/install.yaml
