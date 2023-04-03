#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

rm -rf tmp/
mkdir -p tmp/

# Make clean files with boilerplate
cat << EOF >> tmp/install.yaml
#
# Gateway Config Injector install
#
EOF

for file in `ls config/*.yaml`
do
    echo "---" >> tmp/install.yaml
    echo "#" >> tmp/install.yaml
    echo "# $file" >> tmp/install.yaml
    echo "#" >> tmp/install.yaml
    cat $file >> tmp/install.yaml
done

# Wrap sed to deal with GNU and BSD sed flags.
run::sed() {
  if sed --version </dev/null 2>&1 | grep -q GNU; then
    # GNU sed
    sed -i "$@"
  else
    # assume BSD sed
    sed -i '' "$@"
  fi
}

# Update the image in the install manifest.
echo "setting \"image: ${REGISTRY}/gateway-config-injector:${TAG}\" for tmp/install.yaml"
run::sed \
  "-es|image: danehans/gateway-config-injector:.*$|image: ${REGISTRY}/gateway-config-injector:${TAG}|" \
  "tmp/install.yaml"

echo "Generated:" tmp/install.yaml
