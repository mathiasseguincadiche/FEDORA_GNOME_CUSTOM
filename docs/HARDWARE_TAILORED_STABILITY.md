# Hardware-Tailored Stability — Fedora 44 / GNOME 50

La version 0.8.0 traite la workstation comme une plateforme certifiée, pas comme un PC générique. La cible est MSI MAG B850M MORTAR WIFI + Ryzen 7 7700 + Intel Arc B580 + 2× Crucial T705 + 48 Gio DDR5-6000.

## Principes

- kernel Fedora officiel uniquement ; aucun fork/kernel exotique automatique ;
- aucun `force_probe`, `nomodeset`, désactivation globale ASPM/C-states ou governor performance permanent ;
- firmware/UEFI observé et documenté, jamais modifié automatiquement ;
- Secure Boot, AMD-V et ReBAR font partie du contrat bloquant de plateforme ;
- l'IOMMU est observée et diagnostiquée mais n'est pas un prérequis bloquant pour le contrat actuel `qemu:///system` en NAT sans GPU/device passthrough ;
- le kit XMP 3.0 est exploité via A-XMP à 6000 MT/s, mais cette fréquence est un profil overclock à certifier par stress/RAS, pas une preuve de stabilité par simple boot ;
- le RTL8126-VB 5 GbE doit utiliser le pilote upstream `r8169`; aucun DKMS Realtek ni blacklist de `r8169` n'est autorisé par défaut ;
- l'ALC4080 est traité comme périphérique USB Audio et revalidé après resume avec ALSA/PipeWire/WirePlumber ;
- diagnostics lourds hors du chemin critique system-sleep ;
- journald/coredump persistants et bornés ;
- kdump et watchdog matériel disponibles au diagnostic mais non armés automatiquement ;
- certification finale sur la machine réelle avant verdict PASS.

## Certification fail-closed

`scripts/hardware/workstation-certify.sh` ne peut retourner `VERDICT=PASS` que si les doctors kernel/topologie/power/graphics/storage/network/audio/display sont valides et si les preuves runtime suivantes existent : session GNOME Wayland réelle, uplink par défaut actif, chemin audio ALSA + `snd_usb_audio` + PipeWire/WirePlumber opérationnel, mode Mutter 2560×1440 autour de 240 Hz, stress DDR5-6000 réussi pendant au moins 30 minutes avec le profil A-XMP/XMP 3.0 attendu, et au moins 10 cycles suspend/resume certifiés.

L'absence d'IOMMU seule produit un avertissement tant que le projet reste sans passthrough. Si un futur contrat active un passthrough matériel, `PLATFORM_REQUIRE_IOMMU_FOR_KVM` devra être explicitement repassé à `true`.

## Chaîne de preuve

`topologie → UEFI/Secure Boot/ReBAR → AMD-V + observabilité IOMMU → kernel/microcode → AMD P-State → PCIe → xe/Mesa → Mutter/Wayland → T705/RTL8126/ALC4080 → DDR5-6000 stress >=30 min → 10 cycles suspend/resume → crash forensics`.

Commandes :

```bash
diagnostics/hardware-topology-doctor
diagnostics/kernel-doctor
diagnostics/power-doctor
diagnostics/display-pipeline-doctor
diagnostics/network-doctor
diagnostics/audio-doctor
diagnostics/crash-doctor
diagnostics/last-boot-doctor
scripts/hardware/stability-stress.sh --execute --minutes 30
scripts/hardware/suspend-certify.sh --execute --cycles 10
scripts/hardware/workstation-certify.sh
```
