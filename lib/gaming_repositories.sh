#!/usr/bin/env bash
# Fedora 45 stores vendor definitions under /usr/share/dnf5/repos.d; older installs use /etc.
gaming_steam_repository_file() {
  local root="${1:-}" relative
  root="${root%/}"
  for relative in /etc/yum.repos.d/rpmfusion-nonfree-steam.repo /usr/share/dnf5/repos.d/rpmfusion-nonfree-steam.repo; do
    [[ -r "$root$relative" ]] || continue
    printf '%s\n' "$root$relative"
    return 0
  done
  return 1
}
