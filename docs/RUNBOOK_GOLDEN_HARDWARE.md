# Runbook — durcissement Golden hardware/runtime

Complément de [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) pour les invariants ajoutés à la certification.

## ReBAR absent sur l'Arc B580

```bash
./diagnostics/graphics-doctor
lspci -s "$(basename "$(readlink -f /sys/bus/pci/devices/*/driver/../ 2>/dev/null | head -n1)")" -vv
```

Diagnostic recommandé :

```bash
lspci -Dnnk -d 8086:e20b
lspci -vv -d 8086:e20b | grep -A12 -i 'Resizable BAR'
```

Si le doctor indique ReBAR absent, vérifier dans l'UEFI/BIOS `Above 4G Decoding` et `Resizable BAR`. Ne pas ajouter de paramètre kernel `force_probe` pour contourner ce défaut.

## B580 négociée en x4

```bash
./diagnostics/graphics-doctor
lspci -vv -d 8086:e20b | grep -E 'LnkCap:|LnkSta:'
```

Attendu pour la Golden : capacité ≥ PCIe 4.0, largeur maximale x8 et largeur négociée x8. La vitesse instantanée peut baisser au repos ; ce n'est pas un KO à elle seule.

Une largeur x4 impose de vérifier l'installation physique de la carte, le slot CPU principal et la configuration BIOS avant toute modification Linux.

## T705 négocié en x2 ou capacité < PCIe 5.0

```bash
./diagnostics/storage-doctor
sudo nvme list
sudo nvme list-subsys
lspci -tv
```

Le contrat exige x4 et une capacité maximale ≥ 32 GT/s pour chacun des deux T705. Vérifier slot M.2, partage de lignes PCIe et BIOS. Ne désactiver ni ASPM ni APST par réflexe.

## SMART T705 en KO

```bash
sudo nvme smart-log /dev/nvme0 -o json
sudo nvme smart-log /dev/nvme1 -o json
journalctl -k -b | grep -Ei 'nvme|PCIe Bus Error|AER'
```

Bloquants :

- `critical_warning != 0` ;
- `media_errors != 0` ;
- spare sous le threshold ;
- usure anormalement élevée ;
- température critique ;
- reset/I/O error/controller down ;
- PCIe uncorrected.

`num_err_log_entries` historique seul est informatif : corréler avec le journal courant.

## DDR5 retombée à une vitesse inférieure après reset BIOS

```bash
sudo dmidecode --type 17 | grep -E 'Configured Memory Speed|Speed:'
./diagnostics/baseline-doctor status
```

La modification de vitesse change le fingerprint de baseline. Refaire les tests mémoire 5600/6000 et la certification au lieu de réutiliser les anciennes preuves.

## Kernel candidat installé mais Fedora a démarré

```bash
scripts/kernel/kernel-lifecycle.sh status
uname -r
```

Le comportement est normal si `boot-candidate` n'a pas été planifié. Utiliser :

```bash
scripts/kernel/kernel-lifecycle.sh boot-candidate
sudo reboot
```

Le candidat est booté une fois ; le défaut persistant n'est modifié qu'après `certify`.

## Kernel candidat refuse la certification

```bash
./diagnostics/kernel-doctor
./diagnostics/final-certification status
./diagnostics/software-matrix-doctor diff
```

Vérifier en priorité : fallback Fedora présent, kernel courant exactement égal au candidat, 5 cycles resume, cold-start Nautilus, B580/PCIe/SMART/média/compute et KVM.

## Certification `STALE`

```bash
./diagnostics/software-matrix-doctor diff
```

Ne recréer pas manuellement les markers. Identifier les composants modifiés, exécuter les doctors correspondants puis recertifier.

## EDID attendu absent

```bash
./diagnostics/display-doctor
ls -l /sys/class/drm/card*-*/status
sha256sum /sys/class/drm/card*-*/edid 2>/dev/null
cat ~/.config/fedora-gnome-custom/display-certified.env
```

Le repair ne doit jamais appliquer 1440p/240 Hz à un écran arbitraire. Si l'écran a réellement été remplacé, refaire la baseline pour capturer le nouvel EDID.

## Plusieurs écrans sur la B580

La capture initiale du profil Golden exige un écran cible non ambigu. Déconnecter temporairement les écrans secondaires pendant la certification initiale ou faire évoluer explicitement la politique multi-écran avant de recertifier.

## Backup marker présent mais snapshot Restic absent

```bash
./prepare-preapply-backup.sh
restic snapshots --tag fedora-gnome-custom-preapply
```

L'APPLY doit rester bloqué. La présence de `state/preapply-backup.ok` ne suffit plus : le snapshot exact doit être lisible dans le repository configuré.

## Transaction DNF offline préparée

```bash
dnf offline status
sudo scripts/maintenance/update-system.sh --offline-reboot
```

Après reboot :

```bash
scripts/maintenance/update-system.sh --post-offline
```

Ne considérer pas la nouvelle pile comme Golden avant les postchecks et, si la matrice sensible a changé, la recertification.
