#!/usr/bin/env bash
# A real bridge/DNS/published-port probe. Use one already-cached image ID;
# restoration can exercise the exact same bytes without registry access.
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
image="${1:-}"
[[ $# == 1 && "$image" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'Usage: devops-verify-docker-network.sh sha256:LOCAL_BUSYBOX_IMAGE_ID' >&2; exit 2; }
docker_local() { docker --host unix:///var/run/docker.sock "$@"; }
docker_local image inspect "$image" >/dev/null
token="fgc-network-$$-$RANDOM-$RANDOM"
network="$token"; server="$token-server"; client="$token-client"
network_created=false
server_created=false
client_created=false
cleanup() {
  local result=0
  if $client_created; then docker_local rm -f "$client" >/dev/null 2>&1 || result=1; client_created=false; fi
  if $server_created; then docker_local rm -f "$server" >/dev/null 2>&1 || result=1; server_created=false; fi
  if $network_created; then docker_local network rm "$network" >/dev/null 2>&1 || result=1; network_created=false; fi
  return "$result"
}
on_exit() {
  local result=$?
  trap - EXIT
  if (( result != 0 )); then
    docker_local logs "$server" 2>&1 || true
    echo 'FAIL Docker network qualification; no PASS evidence accepted' >&2
  fi
  cleanup || { echo 'FAIL Docker probe cleanup; inspect the named resources above' >&2; result=1; }
  exit "$result"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'docker_network_probe image=%s resources=%s\n' "$image" "$token"
docker_local image inspect --format 'image_id={{.Id}} repo_digests={{json .RepoDigests}}' "$image"
# An internal bridge still exercises Docker firewall rules and embedded DNS,
# while the probe containers have no external egress.
docker_local network create --internal --label "fgc.network-probe=$token" "$network" >/dev/null
network_created=true
docker_local create --pull=never --name "$server" --label "fgc.network-probe=$token" \
  --network "$network" --network-alias proof-server --publish 127.0.0.1::8080 \
  "$image" sh -c 'mkdir -p /www; printf "%s" "$1" >/www/index.html; exec httpd -f -p 8080 -h /www' sh "$token" >/dev/null
server_created=true
docker_local start "$server" >/dev/null
bindings="$(docker_local inspect --format '{{json (index .NetworkSettings.Ports "8080/tcp")}}' "$server")"
jq -e 'length == 1 and .[0].HostIp == "127.0.0.1" and (.[0].HostPort | test("^[0-9]+$"))' <<<"$bindings" >/dev/null
port="$(jq -r '.[0].HostPort' <<<"$bindings")"
ready=false
for ((attempt=0; attempt<30; attempt++)); do
  response="$(curl --noproxy '*' --fail --silent --show-error --max-time 2 "http://127.0.0.1:$port/" 2>/dev/null || true)"
  if [[ "$response" == "$token" ]]; then ready=true; break; fi
  sleep 1
done
$ready || { echo 'FAIL Docker loopback published HTTP port' >&2; exit 1; }
# Resolve the network alias and reach a different container, not localhost.
docker_local create --pull=never --name "$client" --label "fgc.network-probe=$token" --network "$network" \
  "$image" sh -c 'test "$(wget -T 10 -qO- http://proof-server:8080/)" = "$1"' sh "$token" >/dev/null
client_created=true
docker_local start --attach "$client"
[[ "$(docker_local inspect --format '{{.State.ExitCode}}' "$client")" == 0 ]]
cleanup
printf 'docker_network=PASS cached_image=%s bridge=internal dns=PASS peer_http=PASS published_http=PASS bind=127.0.0.1 cleanup=PASS\n' "$image"
