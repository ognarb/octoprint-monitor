#!/bin/bash

declare -r src_dir="src"

if [[ ! -d "${src_dir}" ]]; then
	echo "*** Source dir not found: ${src_dir}"
	exit 1
fi

declare -r pkg_name=$(cat "${src_dir}/metadata.desktop" | grep X-KDE-PluginInfo-Name | awk '{split($0,a,"="); print a[2]}')
declare -r base_name=$(echo "${pkg_name}" | awk '{cnt=split($0,a,"."); print a[cnt]}')
declare -r pkg_version=$(cat "${src_dir}/metadata.desktop" | grep X-KDE-PluginInfo-Version | awk '{split($0,a,"="); print a[2]}')
declare -r plasmoid_path="../"
declare -r plasmoid_name="${base_name}-${pkg_version}.plasmoid"

echo "PKG_NAME: ${pkg_name}"
echo " VERSION: ${pkg_version}"
echo "PLASMOID: ${plasmoid_name}"

pushd "${src_dir}" > /dev/null
zip -q -r "${plasmoid_path}/${plasmoid_name}" *
ls -ld "${plasmoid_path}/${plasmoid_name}"
popd > /dev/null

