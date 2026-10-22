# Corrections avant installation

Cette revue relie les défauts constatés aux corrections et aux tests. La qualification du poste réel reste une Gate 3 après installation. Un test sur fixtures ou en conteneur ne constitue pas une preuve matérielle.

| Défaut | Correction | Régression |
|---|---|---|
| Configuration Kickstart écrasée, retour implicite à Fedora 44 | Conserver `local.conf` existant ; l’exemple neuf sélectionne Fedora 45 | `test_preinstall_shell_behavior.sh` exécute le bloc réel du guide et vérifie les octets conservés |
| Approbation modifiée après les preuves | Fixer l’approbation avant le dry-run final et le backup | Hash effectif réellement modifié par le drapeau ; refus des preuves périmées dans `test_apply_gate_behavior.sh` |
| Mise à jour déclarée terminée avant exécution | Nouveau boot, identifiant unique retrouvé dans l’historique DNF5 réussi, timestamp cohérent et absence de transaction encore préparée | `test_update_kernel_deferral_behavior.sh`, `test_preinstall_safety.py` |
| `/data` accepté sur un autre disque ou une autre partition du disque système | Enrôlement explicite du numéro de série ; comparaison UUID, modèle, série et WWN des deux NVMe physiques distincts | `test_preinstall_safety.py`, revalidation de baseline dans `test_physical_soak_behavior.sh` |
| nftables refuse une route Tailscale incluse dans le réseau protégé | Fusion des intervalles du set, sans réduire la protection | Vrai `nft` dans un namespace réseau isolé : `test_preinstall_safety.py` |
| Syntaxes SSH Borg rejetées | Valider `ssh://…/…` et `user@host:path` ; refuser les anciens backends Restic | `test_preinstall_shell_behavior.sh` |
| Configuration locale absente des archives lorsque le clone est hors des sources | Copie privée dans l’inventaire pré-APPLY/full, SHA portable et restauration comparée avant attribution du PASS | Vraie archive Borg restaurée dans `test_backup_certification_behavior.sh` |
| Champs SMART absents assimilés à zéro | Exiger toutes les mesures nécessaires, leurs types et leurs bornes | `test_preinstall_safety.py` |
| Anciens cycles de veille comptés après changement de configuration/preuves | Comparer configuration, chaîne Gate 1/2, runtime, écran et contrat pilote ; dédupliquer les cycles | `test_preinstall_shell_behavior.sh` compte puis enregistre de nouvelles preuves sans écraser les anciennes |
| Assistants KVM ignorant les overrides locaux | Chargeur commun validé avant lecture des paramètres | Les trois préambules réels sont exécutés dans `test_preinstall_shell_behavior.sh` |
| Runtime GNOME 51 différent entre laboratoire et installation | Correctif Gtk4-DING, versions RPM et vérificateurs partagés ; installation stable uniquement en production | Patch vérifié sur le ZIP réel dans le laboratoire ; refus de promotion sans RPM stables dans `test_promote_fedora45_behavior.sh` |

## Sources Openclaw persistantes

```text
Crucial T705 #2 — /data — EXT4
├── Documents/       XDG Documents ; Borg
├── Projets/         Git / DevOps ; Borg
├── ISO/             hors backup automatique
├── Jeux/            hors backup automatique
├── IA/Openclaw/     projets et sources Openclaw IA ; Borg
└── libvirt/         données KVM ; export manuel
```

Le module prépare les dossiers sans supprimer leur contenu, avec droits `0750` et labels SELinux `user_home_t` pour les racines utilisateur. Les symlinks vers un autre emplacement sont refusés avant convergence. Les exclusions VM existantes restent applicables à Borg, y compris sous `IA/Openclaw`.

`tests/integration/openclaw-borg-roundtrip.sh` s’exécute uniquement dans un conteneur Docker jetable sans `/data` préexistant. Il sauvegarde puis restaure les vraies racines Openclaw/Projets, vérifie l’exclusion QCOW2 et refuse une sauvegarde après substitution de série. Les réponses matérielles y sont simulées.

## Parcours final

1. Exiger le média final signé et le profil Fedora 45 promu, puis vérifier la CI du commit exact.
2. Préparer le montage EXT4 du second T705, inspecter `baseline-doctor storage-identity`, puis approuver sa série avec `enroll-data NUMERO_DE_SERIE`.
3. Qualifier la baseline et fixer la configuration définitive, approbation comprise.
4. Exécuter le dry-run final puis la sauvegarde pré-APPLY avec preuve de restauration.
5. Exécuter APPLY sur ce même état, redémarrer puis réaliser la qualification matérielle Gate 3.

Toute modification de configuration ou de commit impose de refaire les preuves concernées. Une modification pendant la sauvegarde refuse également la création d’une nouvelle preuve actuelle. Une identité de stockage restaurée sert à comparer les disques ; elle ne remplace pas le contrôle du montage actuel.

## Promotion Fedora 45 encore conditionnelle

Le profil reste `pending`. La disponibilité du média se vérifie sur le [site officiel Fedora Workstation](https://fedoraproject.org/workstation/download/). La bêta du laboratoire ne remplace jamais l’ISO finale signée.

Le laboratoire peut sélectionner explicitement les deux RPM Fedora signés depuis `updates-testing`, dans son seul environnement QEMU. L’installation de production utilise les dépôts `fedora` et `updates` uniquement. `promote-fedora45.py` refuse la promotion si ces versions exactes n’y sont pas disponibles. Le profil promu lie aussi le hash de la liste RPM et celui du correctif Gtk4-DING.

Le [ZIP Gtk4-DING v145](https://extensions.gnome.org/review/download/75162.shell-extension.zip) reste inchangé et authentifié par son SHA-256. Le correctif local produit un `dingManager.js` de SHA-256 `09a128df98fec26550e9dd259b6dd712cd7bb3e0da059f1e82ee5befc623447f`, vérifié à l’installation et pendant l’audit runtime. Une évolution amont nécessite une nouvelle revue de ce contrat.

La finalisation DNF5 utilise la description de commande de l’historique : le [service offline DNF5](https://github.com/rpm-software-management/dnf5/blob/main/dnf5/commands/offline/offline.cpp) préserve cette description, sans recopier le champ `comment` séparé. Un ancien journal lisible ne vaut donc pas preuve d’exécution de la nouvelle transaction.

Les laboratoires téléchargent les certificats depuis les deux encodages officiels décrits dans la [procédure Fedora](https://fedoraproject.org/security/). Un 404 sur `.pgp` peut utiliser `.gpg` ; l’export de la seule empreinte approuvée et la vérification du CHECKSUM signé restent obligatoires. Le workflow de readiness utilise le registre officiel Fedora pour éviter le quota du miroir ECR.

Les installations de paquets des laboratoires réessaient au maximum trois fois la même commande après une panne de miroir. Les arguments et contrôles de signature restent identiques ; un troisième échec conserve le code de retour non nul et interdit toute qualification. Le comportement réussite après panne et refus après épuisement est testé sur fixtures.
