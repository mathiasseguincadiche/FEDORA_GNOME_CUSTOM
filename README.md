# FEDORA_GNOME_CUSTOM

**Golden Workstation 0.14.0** pour Fedora Linux 44 Workstation + GNOME 50, conçue et certifiée pour une workstation AMD Ryzen 7 7700 + Intel Arc B580 + 2× Crucial T705.

Le projet traite l'OS principal comme une infrastructure versionnée :

```text
mesurer → préflight → sauvegarder → converger → qualifier → certifier
```

## Point d'entrée

```bash
./control.sh
```

Mode CLI :

```bash
./control.sh status
./control.sh install dry-run
./control.sh update check
./control.sh update all
./control.sh backup now
./control.sh doctor all
./control.sh kernel status
./control.sh cert status
```

`./menu.sh` reste un alias de compatibilité. Les moteurs spécialisés conservent leurs propres garde-fous.

Voir [`docs/CONTROL_CENTER.md`](docs/CONTROL_CENTER.md).

## Contrat Golden

```text
Fedora 44 fraîche
      ↓
baseline bare-metal
  Ryzen / DDR5 / B580 / ReBAR / PCIe / 2× T705 / EDID
      ↓
FULL DRY-RUN
  commit + configuration effective + module plan + hardware fingerprint
      ↓
backup Restic vérifié
  snapshot réel + integrity check + restore canary
      ↓
APPLY protégé
      ↓
Kernel Vanilla = candidat uniquement
      ↓
boot one-shot du candidat
      ↓
qualification bare-metal
  xe / ReBAR / PCIe / SMART / display / VA-API / OpenCL / GNOME / KVM
      ↓
5 cycles veille/réveil physiques + cold-start Nautilus
      ↓
certification
      ↓
golden-release.json + inventaires exacts
```

Une modification de la configuration locale après le dry-run, un changement matériel/BIOS significatif ou une évolution de la pile runtime invalide les preuves correspondantes.

## Invariants du HOST

- Fedora Linux **44** Workstation ;
- GNOME **50**, Wayland ;
- SELinux **Enforcing** ;
- firewalld actif ;
- **Secure Boot désactivé** par politique ;
- **aucun LUKS / dm-crypt sur les disques locaux du HOST** ;
- Restic reste chiffré pour les sauvegardes externes ;
- aucun `force_probe`, aucun Mesa Git, aucun dépôt GPU tiers ;
- Intel Arc B580 conservée par le HOST, sans passthrough GPU ;
- firmware inventorié, **aucun flash automatique** ;
- Kernel Vanilla stable passe toujours par `candidate → boot-candidate → certify` ;
- au moins un kernel Fedora 44 officiel reste installé comme fallback ;
- KVM/libvirt reste fail-closed vis-à-vis des réseaux HOST protégés.

## Matériel ciblé

| Élément | Contrat |
|---|---|
| Carte mère | MSI MAG B850M Mortar WiFi |
| CPU | AMD Ryzen 7 7700 |
| RAM | 48 Gio, validation 5600 puis 6000 MT/s |
| GPU | Intel Arc B580 `8086:e20b`, pilote `xe` |
| GPU PCIe | ReBAR actif, x8, capacité ≥ PCIe 4.0 |
| SSD système | Crucial T705, Btrfs non chiffré |
| SSD KVM | Crucial T705, EXT4 monté sur `/data` |
| NVMe PCIe | x4, capacité PCIe 5.0 |
| Écran | ASUS ROG Strix OLED XG27AQDMES, 2560×1440/~240 Hz |

Le profil d'affichage est lié à l'**EDID réellement certifié sur un connecteur appartenant à la B580**. L'iGPU Ryzen peut donc rester disponible comme solution de récupération sans rendre le repair ambigu.

## Kernel

Le Golden n'est jamais « le dernier kernel installé ».

```bash
./control.sh kernel candidate
./control.sh kernel boot-candidate
# reboot
./diagnostics/kernel-doctor
./diagnostics/final-certification record-suspend   # après chaque cycle physique
./control.sh kernel certify
```

Le candidat est résolu depuis le repository Kernel Vanilla stable, par NEVRA exacte, avec version minimale et fallback Fedora obligatoires. Une version plus récente n'est jamais promue automatiquement.

## Mises à jour

Les RPM Fedora sont préparés via **DNF5 offline** après backup :

```bash
./control.sh update all
sudo scripts/maintenance/update-system.sh --offline-reboot
# après le reboot
scripts/maintenance/update-system.sh --post-offline
```

Flatpak reste une mise à jour explicite et le firmware reste en consultation uniquement.

## Reproductibilité et preuves

Le projet verrouille :

- le commit Git appliqué ;
- le hash de configuration effective ;
- le hash du plan de modules ;
- le fingerprint hardware ;
- le média Fedora 44 approuvé dans `installer/fedora44-media.lock` ;
- les NEVRA RPM ;
- les commits Flatpak ;
- les hashes des extensions GNOME ;
- BIOS, microcode, firmware, kernel et fallback.

Après certification, `scripts/release/capture-golden-release.sh` produit `golden-release.json` et les inventaires associés.

## Documentation

- [`docs/README.md`](docs/README.md) — portail documentaire ;
- [`docs/INSTALLATION_GUIDE.md`](docs/INSTALLATION_GUIDE.md) — installation bare-metal ;
- [`docs/GOLDEN_WORKSTATION.md`](docs/GOLDEN_WORKSTATION.md) — architecture ;
- [`docs/HARDWARE_BASELINE_CERTIFICATION.md`](docs/HARDWARE_BASELINE_CERTIFICATION.md) — qualification hardware ;
- [`docs/MULTIMEDIA_CODECS.md`](docs/MULTIMEDIA_CODECS.md) — média B580 ;
- [`docs/VIRTUALIZATION.md`](docs/VIRTUALIZATION.md) — KVM/libvirt ;
- [`docs/BACKUP_RESTORE.md`](docs/BACKUP_RESTORE.md) — Restic / recovery ;
- [`docs/GOLDEN_RELEASE.md`](docs/GOLDEN_RELEASE.md) — manifeste de reproductibilité ;
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — runbook principal par symptôme ;
- [`docs/RUNBOOK_GOLDEN_HARDWARE.md`](docs/RUNBOOK_GOLDEN_HARDWARE.md) — ReBAR/PCIe/NVMe/EDID/kernel/offline update ;
- [`docs/adr/README.md`](docs/adr/README.md) — décisions d'architecture.

La source de vérité est :

```text
code + config + tests CI
        ↓
document normatif courant
        ↓
document historique / release note
```

## Sécurité et portée

Le profil est volontairement **sans Secure Boot et sans chiffrement local du HOST**. Il ne protège donc pas le contenu des SSD contre un accès physique offline. En revanche, il conserve SELinux, firewalld, provenance logicielle, contrôle des mutations, KVM fail-closed et sauvegardes Restic chiffrées.

Lire [`SECURITY.md`](SECURITY.md) et [`docs/HOST_SECURITY_POLICY.md`](docs/HOST_SECURITY_POLICY.md) avant de modifier ces invariants.
