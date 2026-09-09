# Modèle documentaire — Fedora 44 Golden Workstation

## Objectif

La documentation fait partie du contrat Golden. Elle doit permettre de **comprendre**, **installer**, **exploiter**, **dépanner** et **certifier** la workstation sans contredire le code exécutable.

Une documentation correcte décrit le système. Une documentation excellente permet aussi au lecteur de savoir **où il se trouve, ce qu'il doit déjà savoir, ce qu'il doit observer et quelle est l'étape suivante**.

Le parcours de lecture recommandé est documenté dans [`LEARNING_PATH.md`](LEARNING_PATH.md).

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

---

## Contrat pédagogique

Tout document opérateur nouveau ou substantiellement modifié doit permettre de répondre clairement aux questions suivantes :

1. **Objectif** — pourquoi ce document ou cette étape existe ?
2. **Public** — à qui s'adresse-t-il ?
3. **Préconditions** — qu'est-ce qui doit déjà être vrai ?
4. **Action** — quelle commande ou procédure faut-il utiliser ?
5. **Résultat attendu** — quelle observation prouve la réussite ?
6. **Critère d'arrêt** — dans quel cas ne faut-il pas continuer ?
7. **Étape suivante** — quel document ou contrôle vient ensuite ?

Ces informations peuvent être regroupées au début du document ou placées aux points où elles sont réellement utiles. Le but n'est pas d'ajouter du texte décoratif, mais d'éliminer les décisions implicites.

### Niveaux de lecture

La documentation doit rester exploitable à plusieurs profondeurs :

- **Découverte** — comprendre le produit et son modèle mental sans lire les détails d'implémentation ;
- **Opérateur** — savoir quoi lancer, pourquoi et comment vérifier le résultat ;
- **Mainteneur / reviewer** — retrouver les invariants, sources de vérité et preuves CI.

Le portail [`README.md`](README.md) et [`LEARNING_PATH.md`](LEARNING_PATH.md) doivent orienter ces trois profils sans dupliquer toute la documentation spécialisée.

### Vocabulaire d'action

Quand la différence est importante pour la sécurité, les documents doivent distinguer :

- **observation** — lecture seule ;
- **plan / dry-run** — validation ou préparation sans convergence réelle ;
- **mutation protégée** — modification soumise à des préconditions ;
- **opération manuelle/destructive** — action explicitement laissée à l'opérateur, par exemple préparation de disque ou flash firmware.

Une commande potentiellement destructive ne doit jamais être noyée dans une séquence sans contexte ni précondition.

### Résultat observable

Une procédure ne doit pas se terminer par « lancer la commande » lorsqu'un résultat observable est disponible. Elle doit indiquer comment reconnaître le succès : état `PASS`, sortie attendue, fichier de preuve, montage, kernel actif, service sain ou diagnostic correspondant.

### Échec et arrêt

Les procédures doivent expliquer quand **ne pas continuer**. Le dépôt est fail-closed : un blocage de baseline, dry-run, backup, Secure Boot, stockage ou certification doit être traité comme une information de sécurité, pas contourné.

Les runbooks doivent suivre autant que possible :

```text
symptôme → observation → diagnostic → correction sûre → revalidation
```

---

## Six familles documentaires

### 1. Normes

Définissent ce que la workstation **doit** être.

- `CAHIER_DES_CHARGES.md`
- `GOLDEN_WORKSTATION.md`
- `EXECUTION_CONTRACT.md`
- `HOST_SECURITY_POLICY.md`
- ADR acceptées

Une norme privilégie les invariants et les critères de conformité. Elle n'a pas vocation à devenir un tutoriel exhaustif.

### 2. Installation

Décrivent la construction du système et la chaîne de preuves.

- `INSTALLATION_GUIDE.md`
- `HARDWARE_BASELINE_CERTIFICATION.md`
- `HARDWARE_STABILITY.md`
- `THREE_GATE_VALIDATION.md`
- `VIRTUALBOX_GNOME_LAB.md`

Une procédure d'installation doit rendre visibles les **préconditions**, les **points de non-retour**, les **checkpoints** et le **résultat final attendu**.

### 3. Guides opérateur

Répondent à « que dois-je lancer ? ».

- `CONTROL_CENTER.md`
- `KVM_QUICKSTART.md`
- `GAMING.md`
- `BACKUP_RESTORE.md`
- `DESKTOP_LIFECYCLE.md`

Un guide opérateur privilégie la tâche courante, les commandes publiques et la validation du résultat. Les détails internes sont liés vers une référence au lieu d'être dupliqués.

### 4. Références techniques

Décrivent l'architecture et les contrats détaillés.

- `VIRTUALIZATION.md`
- `VM_PROFILES.md`
- `KVM_NETWORK.md`
- `VIRTUALIZATION_CLI.md`
- documents GNOME / applications / supply-chain

Une référence optimise la précision et la recherche d'information, pas la lecture linéaire d'un débutant.

### 5. Runbooks

Partent d'un symptôme et indiquent comment diagnostiquer sans contourner les garde-fous.

- `TROUBLESHOOTING.md`
- `RUNBOOK_GOLDEN_HARDWARE.md`
- `RUNBOOK_KVM.md`
- `RUNBOOK_PERSISTENT_DATA_GAMING.md`

Un runbook doit conduire vers une **revalidation explicite** après correction.

### 6. Certification et historique

Décrivent les preuves, la clôture et les artefacts de release.

- `STACK_CERTIFICATION.md`
- `GOLDEN_COMPLETENESS_CLOSURE.md`
- `GOLDEN_RELEASE.md`
- `CHANGELOG.md`

Les documents historiques décrivent ce qui a existé. Ils ne deviennent jamais une procédure active par accident.

---

## Règles de cohérence

1. Une commande documentée doit exister réellement.
2. Les paramètres obligatoires d'un script doivent apparaître dans chaque exemple présenté comme exécutable.
3. Les valeurs réseau, stockage et profils VM doivent venir des fichiers `config/*.conf`.
4. Un guide ne doit pas présenter comme optionnelle une sécurité rendue obligatoire par le code.
5. Les documents historiques peuvent décrire un ancien état, mais ne doivent pas être utilisés comme procédure courante.
6. Les runbooks ne doivent jamais proposer de désactiver SELinux, firewalld ou un garde-fou fail-closed pour « faire passer » un test.
7. Le statut `CODE-READY` et le statut `Golden runtime-certified` restent distincts jusqu'au Gate 3 PASS.
8. Une procédure ne doit pas demander au lecteur de deviner le prochain document lorsqu'un chemin canonique existe.
9. Une mutation importante doit être entourée de ses préconditions et d'un moyen de revalidation.
10. Une notion spécialisée utilisée dans plusieurs documents doit être définie dans `GLOSSARY.md` plutôt que réexpliquée de manière divergente.

---

## Anti-duplication

La pédagogie ne doit pas créer une seconde source de vérité.

- le portail **oriente** ;
- le parcours d'apprentissage **explique l'ordre de lecture** ;
- le guide opérateur **explique quoi faire** ;
- la référence **détaille comment c'est construit** ;
- le runbook **traite les symptômes** ;
- la norme **définit ce qui doit être vrai**.

Lorsqu'un détail est déjà canonique ailleurs, créer un lien plutôt que recopier un bloc susceptible de dériver.

---

## Contrôle CI

`tests/test_documentation_contract.sh` contrôle la structure, les liens et les invariants documentaires principaux.

`tests/test_documentation_code_alignment.sh` contrôle directement les valeurs et exemples sensibles contre la configuration et les scripts :

- KVM/libvirt ;
- stockage `/data` ;
- profils Ubuntu/Windows ;
- hashes Windows/VirtIO obligatoires ;
- runbooks dédiés ;
- messages runtime liés au layout persistant.

Le contrat documentaire contrôle également la présence du parcours pédagogique, des orientations par rôle et des notions de **préconditions**, **résultat attendu**, **critère d'arrêt** et **étape suivante**.

La documentation ne doit donc pas seulement « avoir l'air correcte » : les contrats critiques et la structure de lecture sont testés comme le reste du projet.
