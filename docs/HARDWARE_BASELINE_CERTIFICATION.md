# Hardware Baseline Certification — Phase 0

## But

Certifier la stabilité de la workstation **avant** les personnalisations Fedora/GNOME. La Phase 0 sépare les incidents matériels/firmware/kernel préexistants des changements introduits ensuite par le dépôt.

## Ce que la certification n'automatise pas

Le dépôt ne modifie jamais automatiquement :

- XMP/EXPO ou les timings mémoire ;
- C-States, ASPM ou governor CPU ;
- `s2idle` / `deep` ;
- options DRM expérimentales ;
- partitionnement/formatage ;
- firmware/BIOS.

Les tests longs ou nécessitant un changement BIOS restent opérateur-contrôlés. Le dépôt enregistre leurs résultats et les rattache à une empreinte matériel + BIOS.

## Preuves obligatoires

### 1. DDR5-5600 SPD

Désactiver XMP dans le BIOS, effectuer un test mémoire sérieux (Memtest86+ ou équivalent, plusieurs passes), puis sous Fedora :

```bash
bash diagnostics/baseline-doctor snapshot
bash diagnostics/baseline-doctor record-memory 5600 PASS
```

### 2. DDR5-6000 XMP

Réactiver le profil XMP DDR5-6000, refaire les mêmes tests, puis :

```bash
bash diagnostics/baseline-doctor snapshot
bash diagnostics/baseline-doctor record-memory 6000 PASS
```

Une stabilité à 5600 mais pas à 6000 doit être traitée comme une piste BIOS/IMC/XMP. Le dépôt ne tente pas de corriger le BIOS.

### 3. I/O NVMe soutenu

Tester les deux Crucial T705 avec des transferts contrôlés et non destructifs, tout en surveillant températures, erreurs I/O, NVMe reset et PCIe AER. Après un test réussi :

```bash
bash diagnostics/baseline-doctor record-nvme-io PASS
```

Un reboot spontané, un reset contrôleur ou une erreur PCIe non corrigée invalide le test.

### 4. Suspend / Resume

Effectuer au moins 5 cycles de veille/réveil avec l'Intel Arc B580 et le moniteur 1440p/240 Hz. Après chaque cycle propre :

```bash
bash diagnostics/baseline-doctor record-suspend PASS
```

Ne pas enregistrer PASS si un cycle présente : écran noir durable, corruption graphique, fréquence incorrecte persistante, GPU reset, crash Mutter/GNOME, kernel oops ou reboot.

## Vérification automatique au moment de certifier

`baseline-doctor certify` vérifie aussi :

- Fedora 44 ;
- AMD Ryzen 7 7700 ;
- Intel Arc B580 `8086:e20b` liée au pilote `xe` ;
- présence d'au moins deux Crucial T705 ;
- absence de signatures kernel critiques sélectionnées sur le boot courant ;
- présence des preuves 5600, 6000, NVMe I/O et du nombre minimal de cycles suspend/resume.

```bash
bash diagnostics/baseline-doctor status
bash diagnostics/baseline-doctor certify
```

Le certificat est écrit sous `state/baseline/certified.ok` et n'est pas versionné.

## Invalidation automatique

Le certificat contient une empreinte calculée à partir de :

- carte mère ;
- version/date BIOS ;
- CPU ;
- identité/binding GPU ;
- nombre de T705 détectés.

Si cette empreinte change, `--apply` refuse l'exécution jusqu'à une nouvelle certification.

## Gate APPLY

Le chemin réel exige :

```text
Hardware baseline certifiée
        +
Git propre
        +
Dry-run du même commit
        +
Backup pré-APPLY récent
        +
Confirmation opérateur
        =
APPLY autorisé
```

Le dry-run reste possible sans certificat afin de valider les scripts avant la campagne matérielle.
