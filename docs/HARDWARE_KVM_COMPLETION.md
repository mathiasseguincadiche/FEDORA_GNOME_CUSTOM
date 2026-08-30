# Hardware & KVM Completion — 0.8.1

Cette version ferme les écarts matériels et virtualisation identifiés après la Golden Workstation 0.8.0.

## Firmware et microcode

Le host Fedora 44 installe explicitement `linux-firmware`, `amd-ucode-firmware` pour le Ryzen 7 7700 et `intel-gpu-firmware` pour l'Arc B580. `firmware-doctor` vérifie les paquets, la version microcode exposée par le noyau, les déclarations firmware de `xe`, le firmware RTL8126 disponible et les échecs de chargement firmware du journal courant. `fwupd` reste inventaire-only : aucun flash BIOS/firmware automatique.

## Carte mère certifiée

`hardware-components-doctor` vérifie :

- Realtek 8126-VB avec pilote `r8169` et capacité 5000baseT ;
- chipset Wi-Fi détecté dynamiquement, driver kernel attaché, PHY `iw`, EHT/802.11be et visibilité 6 GHz ;
- contrôleur Bluetooth ;
- ALC4080/USB Audio, `snd_usb_audio` et graphe PipeWire ;
- contrôleurs USB liés à `xhci_hcd`.

Le modèle Wi-Fi exact n'est jamais inventé : le PCI ID réel de la machine reste l'autorité.

## Veille / USB

Le hook sleep capture maintenant réseau, audio USB, xHCI et erreurs USB en plus du GPU/DRM/NVMe. `usb-resume-doctor` fait partie de chaque preuve `final-certification record-suspend`; une erreur xHCI/USB récente invalide le cycle.

## Matrice known-good

`software-matrix-doctor certify` capture BIOS, kernel, linux-firmware, microcode, firmware GPU, Mesa, Mutter, GNOME Shell, Nautilus, QEMU et libvirt. La certification finale enregistre cette matrice. Si une de ces versions change ensuite, le doctor exige une nouvelle validation au lieu de considérer silencieusement la machine comme identique.

## KVM / T705

Avant de créer les VMs, lancer :

```bash
./diagnostics/kvm-io-doctor benchmark
```

Le benchmark est filesystem-safe sur `/data`, exige l'absence de VM active et compare `io_uring` à AIO natif (`libaio`) avec direct I/O. Le meilleur backend devient le profil des nouvelles VMs. Les disques utilisent `cache=none` et `discard=unmap`; `detect_zeroes` et IOThread ne sont ajoutés que si `virt-install --disk=?` confirme explicitement leur support.

## Guest integration

Ubuntu 26.04 et Windows 11 reçoivent :

- channel `org.qemu.guest_agent.0` ;
- VirtIO RNG ;
- balloon mémoire VirtIO ;
- disque et réseau VirtIO.

Windows reçoit aussi le canal SPICE `com.redhat.spice.0`. `Configure-GuestIntegration.ps1` installe les pilotes VirtIO signés depuis l'ISO fourni par l'opérateur, installe QEMU Guest Agent et refuse de valider si un périphérique VirtIO reste en erreur. `runtime_certification.sh` exige que les deux guest agents répondent à `guest-ping`.

## Commandes de certification

```bash
./diagnostics/firmware-doctor
./diagnostics/hardware-components-doctor
./diagnostics/kvm-io-doctor benchmark
./diagnostics/software-matrix-doctor status
./scripts/kvm/runtime_certification.sh
```

La certification bare-metal reste la seule preuve finale ; la CI protège le contrat statique mais ne simule pas le matériel physique.
