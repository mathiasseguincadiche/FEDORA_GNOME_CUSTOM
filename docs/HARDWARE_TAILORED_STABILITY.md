# Hardware-Tailored Stability — Fedora 44 / GNOME 50

La version 0.8.0 traite la workstation comme une plateforme certifiée, pas comme un PC générique. La cible est MSI MAG B850M MORTAR WIFI + Ryzen 7 7700 + Intel Arc B580 + 2× Crucial T705 + 48 Gio DDR5-6000.

## Principes

- kernel Fedora officiel uniquement ; aucun fork/kernel exotique automatique ;
- aucun `force_probe`, `nomodeset`, désactivation globale ASPM/C-states ou governor performance permanent ;
- firmware/UEFI observé et documenté, jamais modifié automatiquement ;
- Secure Boot, AMD-V/IOMMU et ReBAR font partie du contrat de plateforme ;
- le kit XMP 3.0 est exploité via A-XMP à 6000 MT/s, mais cette fréquence est un profil overclock à certifier par stress/RAS, pas une preuve de stabilité par simple boot ;
- le RTL8126-VB 5 GbE doit utiliser le pilote upstream `r8169`; aucun DKMS Realtek ni blacklist de `r8169` n'est autorisé par défaut ;
- l'ALC4080 est traité comme périphérique USB Audio et revalidé après resume avec ALSA/PipeWire/WirePlumber ;
- diagnostics lourds hors du chemin critique system-sleep ;
- journald/coredump persistants et bornés ;
- kdump et watchdog matériel disponibles au diagnostic mais non armés automatiquement ;
- certification finale sur la machine réelle avant verdict PASS.

## Chaîne de preuve

`topologie → UEFI/Secure Boot/IOMMU/ReBAR → kernel/microcode → AMD P-State → PCIe → xe/Mesa → Mutter/Wayland → T705/RTL8126/ALC4080 → DDR5-6000 stress → 10 cycles suspend/resume → crash forensics`.

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
