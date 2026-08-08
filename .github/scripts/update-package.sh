#!/usr/bin/env bash
set -Eeuo pipefail

package_dir=${1:?usage: update-package.sh PACKAGE_DIR}
cd "$package_dir"

upstream_repo=${UPSTREAM_REPO:-SaladDay/cc-switch-cli}
release_json=$(curl --fail --silent --show-error --location --retry 5 --retry-all-errors \
  -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/${upstream_repo}/releases/latest")

tag=$(jq --exit-status --raw-output '.tag_name' <<<"$release_json")
if [[ ! "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  printf 'Unsupported upstream release tag: %s\n' "$tag" >&2
  exit 1
fi
version=${BASH_REMATCH[1]}

current_version=$(sed -n 's/^pkgver=//p' PKGBUILD)
if [[ -z "$current_version" ]]; then
  echo 'PKGBUILD does not contain pkgver' >&2
  exit 1
fi

if [[ "$version" == "$current_version" ]]; then
  echo "Already current: ${version}"
  exit 0
fi

if command -v vercmp >/dev/null 2>&1 && (( $(vercmp "$version" "$current_version") < 0 )); then
  printf 'Refusing to downgrade from %s to %s\n' "$current_version" "$version" >&2
  exit 1
fi

asset_url() {
  jq --exit-status --raw-output --arg name "$1" \
    'first(.assets[] | select(.name == $name) | .browser_download_url)' \
    <<<"$release_json"
}

x86_64_name="cc-switch-cli-v${version}-linux-x64-musl.tar.gz"
aarch64_name="cc-switch-cli-v${version}-linux-arm64-musl.tar.gz"
x86_64_url=$(asset_url "$x86_64_name")
aarch64_url=$(asset_url "$aarch64_name")
checksums_url=$(asset_url checksums.txt)

for url in "$x86_64_url" "$aarch64_url" "$checksums_url"; do
  case "$url" in
    "https://github.com/${upstream_repo}/releases/download/"*) ;;
    *) printf 'Unexpected upstream asset URL: %s\n' "$url" >&2; exit 1 ;;
  esac
done

checksums=$(curl --fail --silent --show-error --location --retry 5 --retry-all-errors "$checksums_url")
checksum_for() {
  awk -v name="$1" '$2 == name { print $1; found = 1 } END { if (!found) exit 1 }' <<<"$checksums"
}

x86_64_sha256=$(checksum_for "$x86_64_name")
aarch64_sha256=$(checksum_for "$aarch64_name")
for checksum in "$x86_64_sha256" "$aarch64_sha256"; do
  [[ "$checksum" =~ ^[[:xdigit:]]{64}$ ]] || {
    printf 'Invalid SHA256 checksum: %s\n' "$checksum" >&2
    exit 1
  }
done

sed -i -E "s/^pkgver=.*/pkgver=${version}/" PKGBUILD
sed -i -E 's/^pkgrel=.*/pkgrel=1/' PKGBUILD
sed -i -E "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('${x86_64_sha256}')/" PKGBUILD
sed -i -E "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('${aarch64_sha256}')/" PKGBUILD

makepkg --printsrcinfo > .SRCINFO
makepkg --verifysource
makepkg --cleanbuild --clean --force

package_file=$(makepkg --packagelist | tail -n 1)
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT
bsdtar --extract --to-stdout --file "$package_file" usr/bin/cc-switch > "$binary"
chmod 755 "$binary"
[[ "$("$binary" --version)" == "cc-switch ${version}" ]] || {
  echo 'Packaged binary version does not match pkgver' >&2
  exit 1
}

echo "Updated and verified cc-switch-cli-musl-bin ${version}-1"
