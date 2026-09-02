# Hardware Baseline Certification

## But

La baseline pré-APPLY prouve uniquement que le matériel est suffisamment sain pour autoriser les mutations système. Elle ne certifie pas suspend/resume avant l'installation des corrections.

La version du projet applicable est celle de [`../VERSION`](../VERSION).

## Preuves automatisées obligatoires

### RAM 5600

Désactiver le profil mémoire 6000 dans le BIOS puis :

```bash
./diagnostics/baseline-doctor run-memory-test 5600
```

Le script vérifie la vitesse configurée et exécute `stress-ng --verify` pendant **3600 secondes (60 minutes)** avec 70 % de la mémoire ciblée par le test. Le log est conservé et son SHA-256 est inclus dans la preuve.

### RAM 6000

Réactiver 6000 MT/s, redémarrer puis :

```bash
./diagnostics/baseline-doctor run-memory-test 6000
```

Le burn-in automatisé dure également **60 minutes**. Le dépôt ne modifie jamais timings/voltage/profil mémoire BIOS.

Pour une première qualification d'une configuration DDR5-6000, une passe mémoire longue hors OS (par exemple Memtest86+) est recommandée en complément. Elle reste une preuve manuelle supplémentaire et ne remplace pas les deux preuves automatisées 5600/6000 exigées par le gate.

### T705 système et DATA

```bash
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
```

`fio` travaille sur un fichier temporaire de 4 Gio du filesystem avec I/O direct et CRC32C. Aucun block device brut n'est écrit.

La certification exige que `/` et `/data` résolvent vers deux NVMe physiques distincts.

## Fingerprint

Le fingerprint contient notamment :

- carte mère ;
- version/date BIOS ;
- UUID plateforme ;
- CPU ;
- Arc B580 + driver ;
- classe mémoire testée ;
- inventaire NVMe avec modèle/serial/firmware ;
- hashes EDID disponibles.

Un changement significatif invalide la certification concernée.

## Suspend/resume

Suspend/resume appartient à la **certification finale post-APPLY**, après installation du kernel et du display recovery. Ceci évite qu'un bug que l'APPLY doit corriger empêche l'installation de son correctif.

## Gate APPLY

```text
RAM 5600 automatisée PASS — burn-in 60 min
RAM 6000 automatisée PASS — burn-in 60 min
T705 root automatisé PASS
T705 /data automatisé PASS
hardware health PASS
        +
dry-run même commit
        +
backup Restic même commit
        +
confirmation opérateur
        =
APPLY autorisé
```

Statut :

```bash
./diagnostics/baseline-doctor status
```

Certification :

```bash
./diagnostics/baseline-doctor certify
```

Après reboot, `diagnostics/final-certification` prend le relais pour kernel, GPU, affichage, desktop, KVM, cold-start Nautilus et cinq cycles suspend/resume.
