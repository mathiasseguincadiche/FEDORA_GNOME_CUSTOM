# Modèle documentaire — Fedora 44 Golden Workstation

## Objectif

La documentation fait partie du contrat Golden. Elle doit permettre de comprendre le système, l'installer, l'exploiter, le dépanner et le certifier sans contredire le code exécutable.

## Ordre d'autorité

```text
code + config + tests
        ↓
documents normatifs courants
        ↓
guides opérateur / références techniques
        ↓
runbooks
        ↓
notes historiques / changelog
```

Une contradiction active entre les deux premiers niveaux est un bug.

## Six familles documentaires

### 1. Normes

Définissent ce que la workstation **doit** être.

- `CAHIER_DES_CHARGES.md`
- `GOLDEN_WORKSTATION.md`
- `EXECUTION_CONTRACT.md`
- `HOST_SECURITY_POLICY.md`
- ADR acceptées

### 2. Installation

Décrivent la construction du système et la chaîne de preuves.

- `INSTALLATION_GUIDE.md`
- `HARDWARE_BASELINE_CERTIFICATION.md`
- `HARDWARE_STABILITY.md`
- `THREE_GATE_VALIDATION.md`
- `VIRTUALBOX_GNOME_LAB.md`

### 3. Guides opérateur

Répondent à « que dois-je lancer ? ».

- `CONTROL_CENTER.md`
- `KVM_QUICKSTART.md`
- `GAMING.md`
- `BACKUP_RESTORE.md`
- `DESKTOP_LIFECYCLE.md`

### 4. Références techniques

Décrivent l'architecture et les contrats détaillés.

- `VIRTUALIZATION.md`
- `VM_PROFILES.md`
- `KVM_NETWORK.md`
- `VIRTUALIZATION_CLI.md`
- documents GNOME / applications / supply-chain

### 5. Runbooks

Partent d'un symptôme et indiquent comment diagnostiquer sans contourner les garde-fous.

- `TROUBLESHOOTING.md`
- `RUNBOOK_GOLDEN_HARDWARE.md`
- `RUNBOOK_KVM.md`
- `RUNBOOK_PERSISTENT_DATA_GAMING.md`

### 6. Certification et historique

Décrivent les preuves, la clôture et les artefacts de release.

- `STACK_CERTIFICATION.md`
- `GOLDEN_COMPLETENESS_CLOSURE.md`
- `GOLDEN_RELEASE.md`
- `CHANGELOG.md`

## Règles de cohérence

1. Une commande documentée doit exister réellement.
2. Les paramètres obligatoires d'un script doivent apparaître dans chaque exemple présenté comme exécutable.
3. Les valeurs réseau, stockage et profils VM doivent venir des fichiers `config/*.conf`.
4. Un guide ne doit pas présenter comme optionnelle une sécurité rendue obligatoire par le code.
5. Les documents historiques peuvent décrire un ancien état, mais ne doivent pas être utilisés comme procédure courante.
6. Les runbooks ne doivent jamais proposer de désactiver SELinux, firewalld ou un garde-fou fail-closed pour « faire passer » un test.
7. Le statut `CODE-READY` et le statut `Golden runtime-certified` restent distincts jusqu'au Gate 3 PASS.

## Contrôle CI

`tests/test_documentation_contract.sh` contrôle la structure, les liens et les invariants documentaires principaux.

`tests/test_documentation_code_alignment.sh` contrôle directement les valeurs et exemples sensibles contre la configuration et les scripts :

- KVM/libvirt ;
- stockage `/data` ;
- profils Ubuntu/Windows ;
- hashes Windows/VirtIO obligatoires ;
- runbooks dédiés ;
- messages runtime liés au layout persistant.

La documentation ne doit donc pas seulement « avoir l'air correcte » : les contrats critiques sont testés comme le reste du projet.
