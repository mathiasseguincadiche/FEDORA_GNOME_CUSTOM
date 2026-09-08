# Golden Release Manifest

Une workstation n'est considérée reproductible que si son état certifié peut être identifié précisément et relié à toute sa chaîne de validation.

Le bundle Golden ne peut être généré qu'en **GATE 3 bare-metal**, après validation de la chaîne Gate 1 WSL2 → Gate 2 VirtualBox.

Après la certification bare-metal, `scripts/release/capture-golden-release.sh` produit un bundle sous `state/releases/` contenant :

```text
golden-release.json
rpm-nevra.tsv
flatpak-commits.tsv
gnome-extensions.tsv
runtime-stack.tsv
enabled-repositories.txt
hardware-ids.txt
fedora44-media.lock
gate1-proof.json
gate2-proof.json
MANIFEST.sha256
```

## Chaîne de validation embarquée

`gate1-proof.json` provient de Fedora 44 sous WSL2 et porte explicitement :

```text
hardware_certification=DEFERRED
manual_visual=N/A
```

`gate2-proof.json` provient de Fedora 44 GNOME sous VirtualBox et porte :

```text
hardware_certification=DEFERRED
manual_visual=PASS
predecessor_sha256=<SHA-256 exact de gate1-proof.json>
```

La capture Golden vérifie la chaîne avant de créer le bundle. Les deux preuves sont ensuite copiées dans le release et incluses dans `MANIFEST.sha256`.

Une preuve WSL2 ou VirtualBox ne devient donc jamais une preuve matérielle : elle reste une prévalidation traçable dans le dossier de la certification physique.

## Contenu du manifeste

`golden-release.json` lie notamment :

- version et commit du projet ;
- `effective_config_sha256` ;
- hash du plan de modules ;
- `validation_gates.chain=PASS` ;
- SHA-256 de la preuve Gate 1 ;
- SHA-256 de la preuve Gate 2 ;
- fingerprint hardware et runtime ;
- kernel courant ;
- kernel Fedora fallback ;
- BIOS et microcode AMD ;
- Arc B580 `8086:e20b`, `xe`, ReBAR, PCIe x8 et EDID certifié ;
- Fedora release/compose/ISO/SHA-256 ;
- hashes des inventaires RPM/Flatpak/extensions/repositories et des IDs PCI/USB/DRM réellement observés.

Les inventaires détaillés conservent les NEVRA RPM, commits Flatpak et hashes d'extensions afin qu'une évolution externe ne soit pas confondue avec l'état certifié historique.

## Conditions de création

Le script refuse de produire une Golden release si l'une de ces conditions manque :

```text
runtime = baremetal
Gate 1 = PASS et actuel
Gate 2 = PASS et actuel
Gate 2 → Gate 1 SHA-256 = valide
baseline hardware = valide
B580 PCIe/ReBAR = valide
T705 SMART/PCIe = valide
kernel Fedora fallback = présent
```

La certification finale ajoute en plus les doctors, le cold-start Nautilus, les cycles suspend/resume et les autres preuves Golden.

## Ce que ce manifeste prouve

Il fournit une **attestation d'état** et de chaîne de validation, pas une promesse que les mirrors Fedora/Flathub permettront éternellement de reconstruire bit-for-bit le même poste. Pour une reconstruction historique totalement autonome, il faut en plus conserver les payloads RPM/Flatpak/ISO nécessaires.

Pour l'usage Golden personnel, la politique retenue est :

```text
source versionnée
  + Gate 1 système/logique
  + Gate 2 desktop/visuel
  + média signé
  + inventaire exact
  + certification hardware/runtime bare-metal
```

Toute modification du commit ou du module plan invalide les preuves Gate 1/2. Toute modification significative de la matrice bare-metal doit être validée puis capturée à nouveau.

## Archive historique longue durée

Après une certification finale `PASS`, le projet fournit un helper opt-in :

```bash
./control.sh cert archive /mnt/archive/golden-2026 \
  /chemin/Fedora-Workstation-Live-44.iso \
  /chemin/offline-rpm-flatpak-cache \
  /chemin/Windows11.iso \
  /chemin/virtio-win.iso
```

`scripts/release/seal-golden-archive.sh` :

- lit le `golden_release_manifest` de la certification finale courante ;
- vérifie d'abord le `MANIFEST.sha256` du bundle Golden ;
- refuse une destination située dans le checkout Git ;
- copie le bundle certifié dans `release/` ;
- copie les payloads explicitement fournis dans `payloads/` ;
- écrit `ARCHIVE.txt` avec commit et configuration effective ;
- génère puis vérifie un nouveau `MANIFEST.sha256` couvrant l'archive complète.

Le helper **ne télécharge rien automatiquement**. Cette limite est volontaire : les médias Windows/VirtIO et les snapshots de dépôts/caches doivent provenir d'une source de confiance choisie par l'opérateur. Pour les RPM/Flatpak, on peut fournir un cache ou miroir offline préalablement constitué ; l'archive scellée conserve ensuite exactement ce qui lui a été remis.

L'archive doit être stockée hors machine ou sur un stockage dédié. Elle complète Restic et le bundle Golden ; elle ne remplace ni le backup courant ni la certification runtime.

Voir [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) pour le protocole complet.
