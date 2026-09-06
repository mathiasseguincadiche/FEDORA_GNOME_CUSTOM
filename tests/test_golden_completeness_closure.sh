#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ echo "golden completeness: $*" >&2; exit 1; }

[[ -x "$ROOT/diagnostics/gaming-doctor" ]] || fail 'gaming-doctor must be executable in Git'
for f in lib/physical_certification.sh diagnostics/physical-runtime-doctor diagnostics/windows-guest-doctor guest/windows-11/configure-guest-integration.ps1 docs/GOLDEN_COMPLETENESS_CLOSURE.md; do [[ -s "$ROOT/$f" ]] || fail "missing $f"; done
grep -Fq 'lib/physical_certification.sh' "$ROOT/lib/bootstrap.sh" || fail 'physical certification library not bootstrapped'

final="$ROOT/diagnostics/final-certification"
grep -Fq 'kvm-domain-doctor" --quiet --require-guests' "$final" || fail 'Gate3 KVM does not require both guests'
grep -Fq 'windows-guest-doctor" --quiet' "$final" || fail 'Windows live contract absent from final certification'
grep -Fq 'backup-doctor" --certify --quiet' "$final" || fail 'strict deep backup contract absent from final certification'
grep -Fq 'physical-runtime-doctor" --quiet status' "$final" || fail 'physical evidence absent from final certification'
for marker in backup_runtime_contract=PASS physical_runtime_contract=PASS windows_guest_contract=PASS kvm_runtime_contract=PASS; do grep -Fq "$marker" "$final" || fail "missing final marker $marker"; done

grep -Fq 'guest-integration.json' "$ROOT/guest/windows-11/configure-guest-integration.ps1" || fail 'Windows marker path missing'
for key in virtio_storage virtio_network virtio_balloon qemu_ga; do grep -Fq "$key" "$ROOT/guest/windows-11/configure-guest-integration.ps1" || fail "Windows marker missing $key"; grep -Fq "$key" "$ROOT/diagnostics/windows-guest-doctor" || fail "host Windows doctor missing $key"; done
grep -Fq 'guest-file-read' "$ROOT/diagnostics/windows-guest-doctor" || fail 'Windows marker is not retrieved with QGA'
grep -Fq 'diagnostics/windows-guest-doctor' "$ROOT/scripts/kvm/runtime_certification.sh" || fail 'KVM runtime certification does not enforce Windows live proof'

baseline="$ROOT/diagnostics/baseline-doctor"
for token in run-cpu-soak enroll-bluetooth list-cooling enroll-cooling; do grep -Fq "$token" "$baseline" || fail "baseline missing $token"; done
for token in 'baseline_evidence_valid cpu-soak' physical_bluetooth_lock_valid physical_cooling_lock_valid bluetooth_identity_lock=PASS cooling_channels=PASS cpu_soak=PASS; do grep -Fq "$token" "$ROOT/lib/baseline.sh" || fail "baseline contract missing $token"; done
grep -Fq 'required controller is not visible' "$ROOT/diagnostics/hardware-components-doctor" || fail 'Bluetooth absence is not fail-closed'
grep -Fq 'pump + CPU fan + system fan enrolled and live' "$ROOT/diagnostics/hardware-components-doctor" || fail 'cooling role proof absent'

physical="$ROOT/diagnostics/physical-runtime-doctor"
for token in gpu-soak network-lan network-wifi audio display-capabilities JE_CONFIRME_AUDIO_GATE3 JE_CONFIRME_VRR_HDR_GATE3 vrr_capable 'payload[0]==0x06'; do grep -Fq "$token" "$physical" || fail "physical contract missing $token"; done
for marker in gpu-soak network-lan network-wifi audio display-capabilities; do grep -Fq "$marker" "$physical" || fail "physical marker missing $marker"; done

grep -Fq '__desktop__' "$ROOT/lib/application_runtime.sh" || fail 'GUI runtime mode missing'
grep -Fq 'gtk-launch' "$ROOT/lib/application_runtime.sh" || fail 'managed GNOME apps are not really launched'
while IFS= read -r pkg; do
  [[ -z "$pkg" || "$pkg" == \#* ]] && continue
  awk -F '\t' -v p="$pkg" '$1=="fedora-rpm" && $2==p && $4=="__desktop__" {ok=1} END{exit !ok}' "$ROOT/manifests/application-runtime-contract.tsv" || fail "managed GTK4 app lacks GUI smoke: $pkg"
done < "$ROOT/manifests/packages-applications-gtk4.txt"

grep -Fq -- '--certify-status' "$ROOT/diagnostics/backup-doctor" || fail 'backup drift status missing'
grep -Fq 'last-full-backup.ok' "$ROOT/diagnostics/backup-doctor" || fail 'current full Restic marker not required'
grep -Fq 'read-data-subset=1/20' "$ROOT/diagnostics/backup-doctor" || fail 'deep Restic integrity check missing'

for f in "$ROOT/lib/physical_certification.sh" "$ROOT/diagnostics/physical-runtime-doctor" "$ROOT/diagnostics/windows-guest-doctor" "$ROOT/diagnostics/final-certification" "$ROOT/diagnostics/baseline-doctor"; do bash -n "$f"; done
echo 'golden completeness closure: PASS'
