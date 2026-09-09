#!/usr/bin/env bash
set -Eeuo pipefail

# CI-only RPM Fusion bootstrap for Fedora 44. MirrorManager remains the primary
# endpoint; download1.rpmfusion.org is the official direct fallback when a
# selected mirror/CDN is temporarily unreachable.
release="${RPMFUSION_FEDORA_RELEASE:-44}"
attempts="${RPMFUSION_BOOTSTRAP_ATTEMPTS:-3}"

[[ "$release" =~ ^[0-9]+$ ]] || { echo "Invalid Fedora release: $release" >&2; exit 2; }
[[ "$attempts" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid retry count: $attempts" >&2; exit 2; }

if command -v rpm >/dev/null 2>&1; then
  runtime_release="$(rpm -E '%fedora' 2>/dev/null || true)"
  if [[ "$runtime_release" =~ ^[0-9]+$ && "$runtime_release" != "$release" ]]; then
    echo "RPM Fusion bootstrap release mismatch: runtime Fedora=$runtime_release requested=$release" >&2
    exit 1
  fi
fi

install_release() {
  local channel="$1"
  local package="rpmfusion-${channel}-release"
  local filename="${package}-${release}.noarch.rpm"
  local attempt url
  local -a endpoints=(
    "https://mirrors.rpmfusion.org/${channel}/fedora/${filename}"
    "https://download1.rpmfusion.org/${channel}/fedora/${filename}"
  )

  if rpm -q "$package" >/dev/null 2>&1; then
    echo "$package already installed"
    return 0
  fi

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    for url in "${endpoints[@]}"; do
      echo "RPM Fusion ${channel}: cycle ${attempt}/${attempts} via ${url}"
      if timeout 90 dnf -y install "$url"; then
        rpm -q "$package"
        return 0
      fi
    done
    if ((attempt < attempts)); then
      sleep $((attempt * 5))
    fi
  done

  echo "RPM Fusion ${channel}: all official bootstrap endpoints failed" >&2
  return 1
}

install_release free
install_release nonfree

rpm -q rpmfusion-free-release rpmfusion-nonfree-release
repos="$(dnf repolist --all)"
grep -Fq 'rpmfusion-free' <<<"$repos"
grep -Fq 'rpmfusion-nonfree' <<<"$repos"

echo 'RPM Fusion bootstrap: PASS'
