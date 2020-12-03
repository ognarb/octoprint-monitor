#!/bin/bash

declare -r src_dir="src"

if [[ ! -d "${src_dir}" ]]; then
	echo "*** Source dir not found: ${src_dir}"
	exit 1
fi

declare -r pkg_name=$(cat "${src_dir}/metadata.desktop" | grep X-KDE-PluginInfo-Name | awk '{split($0,a,"="); print a[2]}')
declare -r base_name=$(echo "${pkg_name}" | awk '{cnt=split($0,a,"."); print a[cnt]}')
declare -r pkg_version=$(cat "${src_dir}/metadata.desktop" | grep X-KDE-PluginInfo-Version | awk '{split($0,a,"="); print a[2]}')
declare -r plasmoid_path="$(pwd)"
declare -r plasmoid_name="${base_name}-${pkg_version}.plasmoid"

echo "PKG_NAME: ${pkg_name}"
echo " VERSION: ${pkg_version}"
echo "PLASMOID: ${plasmoid_name}"

tmp="$(mktemp -d "/tmp/${base_name}.XXXXXX")"

echo "${tmp}"
cp -a "${src_dir}"/* "${tmp}"

if [[ -f "${plasmoid_path}/${plasmoid_name}" ]]; then
	echo "*** File already exists: ${plasmoid_path}/${plasmoid_name}"
	exit 1
fi

op_api_url=
op_api_key=
op_snapshot_url=
declare -r cfg_template_file="${tmp}/contents/config/main-template.xml"
declare -r cfg_config_file="${tmp}/contents/config/main.xml"

pushd "${tmp}" > /dev/null
cat "${cfg_template_file}" | sed -e "s/{OCTOPRINT_API_URL}/${op_api_url}/g" | sed -e "s/{OCTOPRINT_API_KEY}/${op_api_key}/g" | sed -e "s/{OCTOPRINT_SNAPSHOT_URL}/${op_snapshot_url}/g" > "${cfg_config_file}"
rm -vf "${cfg_template_file}"

zip -q -r "${plasmoid_path}/${plasmoid_name}" *
ls -ld "${plasmoid_path}/${plasmoid_name}"

popd > /dev/null

