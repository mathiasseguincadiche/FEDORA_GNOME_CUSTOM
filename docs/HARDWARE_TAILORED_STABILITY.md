# Hardware-Tailored Stability — Fedora 44 / GNOME 50

La version 0.8.0 traite la workstation comme une plateforme certifiée, pas comme un PC générique. La cible est MSI MAG B850M MORTAR WIFI + Ryzen 7 7700 + Intel Arc B580 + 2× Crucial T705 + GNOME 50 Wayland.

## Principes

- kernel Fedora officiel uniquement ; aucun fork/kernel exotique automatique ;
- aucun `force_probe`, `nomodeset`, désactivation globale ASPM/C-states ou governor performance permanent ;
- firmware/UEFI observé et documenté, jamais modifié automatiquement ;
- ReBAR obligatoire pour l'Arc ;
- DDR5-6000 considérée comme un profil à certifier par stress/RAS, pas comme une preuve de stabilité par simple boot ;
- diagnostics lourds hors du chemin critique system-sleep ;
- journald/coredump persistants et bornés ;
- kdump et watchdog matériel disponibles au diagnostic mais non armés automatiquement ;
- certification finale sur la machine réelle avant verdict PASS.

## Chaîne de preuve

`topologie → kernel/microcode → AMD P-State → PCIe/ReBAR → xe/Mesa → Mutter/Wayland → NVMe/réseau/audio → stress → 10 cycles suspend/resume → crash forensics`.

Commandes :

```bash
diagnostics/hardware-topology-doctor
diagnostics/kernel-doctor
diagnostics/power-doctor
diagnostics/display-pipeline-doctor
diagnostics/crash-doctor
diagnostics/last-boot-doctor
scripts/hardware/stability-stress.sh --execute --minutes 30
scripts/hardware/suspend-certify.sh --execute --cycles 10
scripts/hardware/workstation-certify.sh
```
