# Stabilité matérielle — Golden Workstation

Politique : **mesurer → reproduire → corriger → recertifier**, jamais appliquer une collection de tweaks kernel au hasard.

La version applicable est celle de [`../VERSION`](../VERSION).

## Arc B580 / xe

Le GPU doit rester `8086:e20b` lié à `xe`.

Les contrôles couvrent Vulkan, VA-API, firmware, journal xe/DRM et état Wayland/Mutter. Aucun `force_probe` n'est autorisé.

```bash
./diagnostics/firmware-doctor
./diagnostics/graphics-doctor
./diagnostics/arc-compute-doctor
```

## Kernel

Le profil utilise Fedora Kernel Vanilla stable avec plancher 7.2.2 et garde les kernels Fedora installés comme fallback.

Secure Boot actif bloque ce chemin par défaut tant qu'un workflow de confiance/signature n'a pas été choisi explicitement.

Aucun retrait agressif des kernels Fedora de secours n'est prévu.

## Display

Après resume ou power-cycle écran, le problème de texte dégradé est traité d'abord comme une renégociation display/KMS/Mutter possible.

Le repair réapplique :

- 1440p/~240 Hz ;
- scale 1.0 ;
- SDR/default ;
- Full RGB.

`gdctl`, `drm_info` et les journaux xe/DRM/PCIe sont capturés pour corrélation.

## Suspend/resume

Le hook système conserve les captures pre/post. Le watcher user observe les événements prévus de reprise/session/display et exécute le display repair dans la vraie session GNOME.

Cinq cycles physiques uniques sont requis après APPLY/reboot par `final-certification`.

Aucun `s2idle`/`deep`, ASPM, APST ou C-State n'est forcé globalement sans preuve spécifique.

## Stockage

Les deux T705 sont identifiés par modèle/serial/firmware.

La baseline exécute un `fio` filesystem-safe séparé sur `/` et `/data` et vérifie qu'il s'agit de deux NVMe physiques distincts.

SMART/NVMe et erreurs PCIe restent surveillés.

Pour le stockage KVM sur `/data`, `kvm-io-doctor` sélectionne le backend supporté à partir d'une mesure filesystem-safe plutôt qu'un choix de tuning théorique.

## Réseau KVM

Le réseau des VM utilise un guard fail-closed séparé du firewall global. Un changement d'uplink installe un mode d'urgence restrictif avant de recalculer les CIDR normaux.

Une panne de recalcul coupe donc le forwarding KVM externe plutôt que de conserver une ancienne hypothèse LAN.

Voir [`KVM_NETWORK.md`](KVM_NETWORK.md).

## Reboot anormal

`scripts/collect-boot-failure.sh` reste le collecteur de référence pour :

- journal précédent ;
- xe/DRM ;
- ACPI ;
- PCIe AER ;
- NVMe ;
- MCE/EDAC ;
- watchdog ;
- coredumps ;
- pstore.

Pour le runbook par symptôme, voir [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).
