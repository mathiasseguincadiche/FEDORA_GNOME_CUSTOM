# Validation en trois phases — WSL2 → VirtualBox → bare-metal

Cette procédure est l'ordre officiel de qualification de la Golden Workstation.

```text
GATE 1 — Fedora 44 / WSL2
Prévalidation système + logique
        │
        │ preuve JSON portable Gate 1
        ▼
GATE 2 — Fedora 44 / VirtualBox
Validation GNOME / Nautilus / Ptyxis + contrôle visuel humain
        │
        │ preuve JSON portable Gate 2 liée au SHA-256 de Gate 1
        ▼
GATE 3 — Fedora 44 / BARE-METAL
Installation réelle + certification matérielle/logicielle complète
        │
        ▼
final-certification PASS
        │
        ▼
golden-release.json
```

## Règles absolues

1. Les trois phases doivent utiliser **le même commit Git** et le même `manifests/module-plan.conf`.
2. Le worktree doit être propre lors de la création/importation d'une preuve.
3. Une modification du projet après Gate 1 ou Gate 2 rend les anciennes preuves invalides : les gates doivent être rejouées.
4. Gate 1 et Gate 2 portent explicitement `hardware_certification=DEFERRED`.
5. Gate 1 et Gate 2 ne peuvent jamais produire `final-certification PASS` ni `golden-release.json`.
6. Seul un runtime réellement détecté `baremetal` peut exécuter Gate 3.
7. Gate 2 doit référencer exactement le SHA-256 de la preuve Gate 1 importée.
8. Gate 3 refuse la certification si la chaîne Gate 1 → Gate 2 n'est pas présente, actuelle et intacte.

## Commandes communes

```bash
./control.sh validate help
./control.sh validate status
```

Import d'une preuve portable :

```bash
./control.sh validate import /chemin/vers/gate1-<commit>.json
./control.sh validate import /chemin/vers/gate2-<commit>.json
```

Export vers un dossier partagé, une clé USB ou un autre support de transfert :

```bash
./control.sh validate export 1 /chemin/export
./control.sh validate export 2 /chemin/export
```

Chaque export est accompagné d'un fichier `.sha256`.

---

# Gate 1 — Fedora 44 sous WSL2

## Objectif

Gate 1 valide le **code de validation**, la cohérence système et les décisions fail-closed. Ce n'est pas une certification du matériel physique.

### Validé

- Fedora 44 userland ;
- détection WSL2 ;
- outils système requis ;
- schéma de configuration ;
- catalogue/modules et ordre des dépendances ;
- syntaxe Bash ;
- totalité de la suite de contrats déclarée dans `.github/workflows/tests.yml` ;
- logique dry-run / mutation ;
- guards runtime ;
- logique Kernel Vanilla candidat/certifié ;
- logique Restic et APPLY gates ;
- logique KVM fail-closed ;
- logique B580/T705/EDID via les contrats et fixtures du dépôt.

### Explicitement non certifié

- PCI réel `8086:e20b` ;
- pilote `xe` natif ;
- ReBAR ;
- PCIe x8 de la B580 ;
- SMART/PCIe x4 des T705 ;
- BIOS/UEFI ;
- EDID physique ;
- 1440p/~240 Hz ;
- VA-API/OpenCL sur la B580 physique ;
- suspend/resume firmware ;
- KVM host réel.

## Exécution

Dans Fedora 44 WSL2 :

```bash
git switch main
git pull --ff-only
git status --short
./control.sh validate gate1 run
```

Résultat attendu :

```text
GATE 1 PASS
hardware_certification=DEFERRED
```

La preuve est créée dans :

```text
state/validation/outbox/gate1-<commit>.json
```

Exporter la preuve vers Windows ou un support partagé :

```bash
./control.sh validate export 1 /mnt/c/GoldenValidation
```

---

# Gate 2 — Fedora 44 GNOME sous VirtualBox

## Objectif

Gate 2 valide le **desktop réel dans une VM graphique** sans prétendre certifier le matériel hôte.

Le laboratoire VirtualBox est volontairement séparé du `install.sh --apply` de production.

## Pré-requis VM

- Oracle VirtualBox ;
- Fedora Linux 44 ;
- GNOME Shell 50 ;
- session Wayland ;
- utilisateur desktop non-root ;
- D-Bus utilisateur actif ;
- même commit Git que Gate 1.

## 1. Importer Gate 1

Copier la preuve Gate 1 dans la VM puis :

```bash
./control.sh validate import /chemin/gate1-<commit>.json
./control.sh validate gate2 status
```

## 2. Voir le périmètre exact

```bash
./control.sh validate gate2 plan
```

## 3. Converger le desktop de test

```bash
./control.sh validate gate2 apply
```

Le LAB installe/valide notamment :

- GNOME core et portals ;
- Nautilus ;
- GVfs ;
- Sushi ;
- File Roller/Nautilus ;
- préwarm utilisateur Nautilus ;
- applications GTK4/libadwaita gérées ;
- Ptyxis natif ;
- DING ;
- Show Desktop Plus ;
- Resource Monitor ;
- réglages GNOME ciblés.

Si GNOME demande une reconnexion après installation d'extensions : se déconnecter/reconnecter puis relancer `gate2 check`.

## 4. Contrôles automatisés

```bash
./control.sh validate gate2 check
```

Ces contrôles couvrent notamment :

- identité VirtualBox ;
- Fedora 44 ;
- GNOME Shell 50 ;
- Wayland ;
- production APPLY toujours bloqué ;
- baseline bare-metal toujours bloquée ;
- extensions installées, épinglées et activées ;
- réglages DING / Show Desktop Plus / Resource Monitor ;
- Nautilus/GVfs ;
- Ptyxis ;
- XDG portals.

## 5. Contrôle visuel humain obligatoire

Vérifier réellement à l'écran :

- GNOME Shell sans crash ni défaut graphique évident ;
- icônes DING conformes ;
- corbeille visible selon la politique ;
- bouton Show Desktop Plus fonctionnel ;
- `Super+D` fonctionnel ;
- Resource Monitor lisible dans la barre supérieure ;
- Nautilus se lance et navigue correctement ;
- intégration archives/prévisualisation cohérente ;
- Ptyxis se lance normalement ;
- aucune bannière répétée d'erreur d'extension ;
- aucune régression évidente de disposition.

Puis signer Gate 2 :

```bash
./control.sh validate gate2 sign
```

Le script exige la phrase exacte :

```text
JE_VALIDE_VISUELLEMENT_GATE2
```

La preuve Gate 2 contient `manual_visual=PASS` et le SHA-256 exact de la preuve Gate 1.

Exporter ensuite les deux preuves :

```bash
./control.sh validate export 1 /chemin/export
./control.sh validate export 2 /chemin/export
```

---

# Gate 3 — Fedora 44 réellement installé sur le PC

## Objectif

Gate 3 est **la seule certification Golden autoritaire**.

Elle doit être exécutée sur la machine physique cible :

- Ryzen 7 7700 ;
- MSI MAG B850M Mortar WiFi ;
- Intel Arc B580 12 Go ;
- deux Crucial T705 ;
- écran ASUS OLED 2560×1440/~240 Hz ;
- pile KVM/libvirt ;
- stockage/backup réels.

## 1. Installer Fedora 44 avec le média verrouillé

Suivre `INSTALLATION_GUIDE.md` et vérifier le média avec :

```bash
installer/verify-fedora44-media.sh ...
```

Conserver les invariants :

```text
Secure Boot           OFF
LUKS local            interdit
SELinux               enforcing
firewalld             actif
Arc B580              host-only
Kernel Fedora         fallback obligatoire
Firmware              aucun flash automatique
```

## 2. Utiliser exactement le même commit

Après installation :

```bash
git switch main
git pull --ff-only
git status --short
git rev-parse HEAD
```

Le SHA doit correspondre aux preuves Gate 1 et Gate 2.

## 3. Importer les preuves dans l'ordre

```bash
./control.sh validate import /chemin/gate1-<commit>.json
./control.sh validate import /chemin/gate2-<commit>.json
./control.sh validate gate3 status
```

Gate 2 est rejetée si elle ne référence pas exactement la preuve Gate 1 importée.

## 4. Convergence bare-metal

Exécuter la séquence Golden habituelle :

```bash
./control.sh install dry-run
./control.sh install backup
./control.sh install apply
```

Puis qualifier le Kernel Vanilla candidat selon le lifecycle documenté :

```bash
./control.sh kernel candidate
./control.sh kernel boot-candidate
# reboot
```

## 5. Preuves physiques obligatoires

Gate 3 certifie notamment :

- BIOS/UEFI et politique Secure Boot OFF ;
- absence de chiffrement local LUKS ;
- firmware/microcode runtime ;
- B580 `8086:e20b` ;
- driver `xe` ;
- ReBAR ;
- PCIe x8 ;
- Vulkan ;
- vrai kernel OpenCL ;
- vrai encode/decode VA-API ;
- EDID physique ;
- 2560×1440/~240 Hz ;
- display repair lié à l'EDID ;
- deux T705 ;
- SMART strict ;
- PCIe 5.0 x4 ;
- absence d'erreur AER/NVMe critique ;
- GNOME/Nautilus/Ptyxis/portals ;
- KVM/libvirt et isolation réseau fail-closed ;
- Restic externe chiffré + restore canary ;
- cold-start Nautilus ;
- cinq cycles physiques suspend/resume uniques.

Enregistrer chaque cycle physique :

```bash
./control.sh validate gate3 record-suspend
```

## 6. Certification finale

Lorsque toutes les preuves sont présentes :

```bash
./control.sh validate gate3 certify
```

Le `final-certification` vérifie lui-même la chaîne Gate 1 → Gate 2 : appeler directement le doctor ne permet pas de contourner cette règle.

Résultat final :

```text
state/final/certified.ok
state/releases/<timestamp>-<sha>/golden-release.json
```

Le bundle Golden contient aussi :

```text
gate1-proof.json
gate2-proof.json
MANIFEST.sha256
```

et `golden-release.json` enregistre les SHA-256 des deux preuves.

---

# Lecture des statuts

```bash
./control.sh validate status
```

Exemple avant Gate 3 :

```text
runtime=baremetal
project_commit=<sha>
gate1=PASS
gate2=PASS
chain=PASS
gate3_final=PENDING
```

Après certification finale :

```text
gate1=PASS
gate2=PASS
chain=PASS
gate3_final=PASS
```

# Ce que signifie réellement PASS

| Gate | PASS signifie | PASS ne signifie pas |
|---|---|---|
| Gate 1 / WSL2 | code, contrats et logique système cohérents | matériel physique validé |
| Gate 2 / VirtualBox | desktop GNOME/Nautilus/Ptyxis validé en VM + contrôle visuel | B580/T705/BIOS/EDID physiques validés |
| Gate 3 / bare-metal | Golden Workstation matériel + logiciel certifiée | — |

Cette séparation empêche une preuve virtuelle de devenir silencieusement une preuve matérielle.
