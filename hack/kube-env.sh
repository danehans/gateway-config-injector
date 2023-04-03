#!/bin/bash

# Some useful colors.
if [[ -z "${color_start-}" ]]; then
  declare -r color_start="\033["
  declare -r color_red="${color_start}0;31m"
  declare -r color_yellow="${color_start}0;33m"
  declare -r color_green="${color_start}0;32m"
  declare -r color_norm="${color_start}0m"
fi

# Returns the server version as MMmmpp, with MM as the major
# component, mm the minor component, and pp as the patch
# revision. e.g. 0.7.1 is echoed as 701, and 1.0.11 would be
# 10011. (This makes for easy integer comparison in bash.)
function kube_server_version() {
  local server_version
  local major
  local minor
  local patch

  # This sed expression is the POSIX BRE to match strings like:
  # Server Version: &version.Info{Major:"0", Minor:"7+", GitVersion:"v0.7.0-dirty", GitCommit:"ad44234f7152e9c66bc2853575445c7071335e57", GitTreeState:"dirty"}
  # and capture the GitVersion portion (which has the patch level)
  server_version=$(${KUBECTL} --match-server-version=false version | grep "Server Version:")
  read major minor patch < <(
    echo ${server_version} | \
      sed "s/.*GitVersion:\"v\([0-9]\{1,\}\)\.\([0-9]\{1,\}\)\.\([0-9]\{1,\}\).*/\1 \2 \3/")
  printf "%02d%02d%02d" ${major} ${minor} ${patch} | sed 's/^0*//'
}
