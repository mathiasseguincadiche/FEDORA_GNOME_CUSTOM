# Golden Workstation — completeness closure

This runbook closes the final gaps between a correct Fedora 44 deployment and a **physically certified Golden Workstation**. None of the long-running or interactive tests below runs automatically during APPLY.

## Scope

The closure makes the following contracts fail-closed on bare metal:

- `gaming-doctor` is mandatory because Gaming is part of the canonical Golden profile;
- Gate 3 requires both Golden KVM guests and a live Windows VirtIO/QEMU-GA proof;
- final backup certification requires a current full Restic snapshot plus repository reachability and a deep integrity sample;
- the Ryzen 7 7700 has a dedicated sustained CPU soak before baseline certification;
- cooling certification identifies three distinct live channels: AIO pump, CPU/radiator fan, system fan;
- the Bluetooth controller is enrolled by USB identity and must remain bound to Fedora `btusb`;
- wired and Wi-Fi host networking each receive a real DHCP/IP/route/DNS/HTTPS proof; Wi-Fi additionally proves association;
- audio receives a playback, capture and human confirmation proof;
- every managed GTK4 application is activated through its installed `.desktop` launcher under Wayland;
- the Arc B580 receives a sustained Vulkan/3D soak with post-run `xe`/PCIe/AER inspection;
- the certified OLED display must expose VRR and HDR capability and receives a human confirmation of active VRR/HDR operation.

All physical runtime evidence is bound to the physical hardware/kernel/driver fingerprint and effective configuration. Hardware or relevant runtime drift makes the evidence stale.

## 1. Pre-APPLY hardware baseline additions

Run on the final physical Fedora 44 host.

### Bluetooth identity

```bash
./diagnostics/baseline-doctor enroll-bluetooth
```

The enrolled controller must remain the same USB identity and use the Fedora in-tree `btusb` driver.

### Cooling channel enrollment

First list the NCT6687D channels while the pump and fans are running:

```bash
./diagnostics/baseline-doctor list-cooling
```

Identify three **different** channels and enroll them in this order:

```bash
./diagnostics/baseline-doctor enroll-cooling fanN fanN fanN
#                                               pump CPU  system
```

The enrollment is refused if a selected channel is absent or below the minimum live RPM threshold. The baseline and hardware doctor subsequently require all three channels to remain live.

### Ryzen soak

```bash
./diagnostics/baseline-doctor run-cpu-soak
```

Default duration: 1800 seconds. The test uses all CPUs with `stress-ng --verify`, samples `k10temp`, requires temperature below 95 °C by default, verifies AMD P-State/boost before and after, and rejects MCE, uncorrected EDAC, thermal-critical and hard-lockup signals.

Then complete the existing RAM/NVMe tests and certify the baseline:

```bash
./diagnostics/baseline-doctor run-memory-test 5600
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

The baseline certificate cannot be created without the CPU soak, Bluetooth lock and cooling-channel lock.

## 2. Windows 11 live guest proof

Inside the final Windows 11 guest, attach the trusted VirtIO media and run as Administrator:

```powershell
.\Configure-GuestIntegration.ps1
```

The script now refuses unhealthy VirtIO devices and explicitly requires healthy VirtIO storage, network and balloon devices plus a running QEMU Guest Agent. It writes:

```text
C:\ProgramData\FedoraGnomeCustom\guest-integration.json
```

The host retrieves this marker through QEMU Guest Agent; shared folders or guest credentials are not used.

Host verification:

```bash
./diagnostics/windows-guest-doctor
```

Gate 3 also requires `kvm-domain-doctor --require-guests`, so missing Ubuntu or Windows domains are fatal.

## 3. Full Restic proof before final Gate 3

Create a current full backup from the same Git commit that will be certified:

```bash
./scripts/backup/backup-now.sh
./diagnostics/backup-doctor --certify
```

`--certify` is strict. It requires the current full snapshot marker, matching Git commit, integrity marker, freshness, repository/password resolution, repository reachability, and `restic check --read-data-subset=1/20`.

## 4. Physical runtime proofs

Import the current Gate 1 and Gate 2 proofs first, then run the following after the final applications and KVM guests are in place.

### Arc B580 Vulkan soak

```bash
./control.sh validate gate3 gpu-soak
```

Default: two concurrent Vulkan cubes for 900 seconds. Any Vulkan process failure or critical `xe`, uncorrected PCIe or AER signal blocks the proof.

### Wired host connectivity

```bash
./control.sh validate gate3 network-lan
```

Requires a connected NetworkManager Ethernet interface, global IPv4, default route, DNS and real HTTPS access. IPv6 is validated when a global IPv6 address is present.

### Wi-Fi host connectivity

```bash
./control.sh validate gate3 network-wifi
```

Requires the same network proof plus a real `iw` association.

The two proofs can be captured at different times; both must remain valid for the current physical fingerprint.

### Audio playback and capture

```bash
./control.sh validate gate3 audio-cert
```

The test runs an ALSA speaker tone and records a short microphone sample. It then requires the exact physical confirmation phrase printed by the command. This prevents a silent device-enumeration-only PASS.

### VRR and HDR

```bash
./control.sh validate gate3 display-cert
```

The display proof requires:

1. the existing exact Arc B580 connector/EDID and 2560×1440 ~240 Hz contract;
2. DRM VRR capability;
3. a CTA HDR Static Metadata block in the monitor EDID;
4. explicit human confirmation after VRR and HDR have been enabled/tested in GNOME.

For the target ASUS ROG Strix OLED XG27AQDMES, VRR/Adaptive-Sync, HDR10 and 240 Hz are therefore part of the Golden contract rather than optional features.

### Status

```bash
./control.sh validate gate3 physical-status
```

A PASS requires these five current markers: `gpu-soak`, `network-lan`, `network-wifi`, `audio`, and `display-capabilities`.

## 5. Final KVM runtime certification

Start both Golden guests and ensure the Windows marker exists, then run:

```bash
./scripts/kvm/runtime_certification.sh
```

The public runtime certification keeps the existing host, Ubuntu, XML and fail-closed network tests, and now adds the strict live Windows QGA proof.

## 6. Five physical suspend/resume cycles

Record five unique real cycles as already required:

```bash
./control.sh validate gate3 record-suspend
```

Repeat after each separate physical suspend/resume cycle.

## 7. Final Golden certification

```bash
./control.sh validate gate3 certify
```

A final PASS now requires, in addition to the existing contracts:

- valid CPU-soak/Bluetooth/cooling baseline;
- strict Restic certification;
- all five physical runtime proofs;
- Gaming enabled and `gaming-doctor` PASS on the Arc B580/Wayland/240 Hz stack;
- both KVM domains;
- live Windows VirtIO/QGA proof;
- complete managed application runtime activation;
- the existing five suspend/resume cycles and Nautilus cold-start evidence.

Only this physical command may create the final Golden marker. CI, WSL2 and VirtualBox still cannot certify the workstation hardware.
