# Refonte de la documentation — novembre 2026

> **Compte rendu.** Il décrit la refonte telle qu'elle s'est terminée le 4 novembre 2026, et n'est pas tenu à jour. Les règles en vigueur sont dans le [guide du contributeur](../../CONTRIBUTING.md#écrire-la-documentation).

## Objectif

Après la promotion de Fedora 45 et la préversion 0.24.0, la documentation devait servir deux publics : le propriétaire du PC, qui installe et entretient le poste, et un visiteur qui découvre le projet. Trois décisions ont cadré le travail :

- chaque guide de `docs/` porte un bloc de métadonnées qui dit quand et comment il a été vérifié ;
- les schémas Mermaid sont remplacés par des paires `.drawio` (source éditable) et `.svg` (export) ;
- un audit d'abord, puis une PR par chantier, chaque guide relu contre le code et non contre l'ancienne documentation.

## Les chantiers

| Chantier | Périmètre | PR |
|---|---|---|
| C1 | Conventions de rédaction dans `CONTRIBUTING.md` ; contrôles de `tests/test_docs_integrity.py` et leurs tests de comportement | [#171](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/171) |
| C2 | README pour deux publics ; source unique du parcours d'installation | [#173](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/173) |
| C3 | Sept schémas `.drawio` / `.svg` à la place de Mermaid | [#174](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/174) |
| C4 | Installation et qualification en procédure vérifiable | [#175](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/175) |
| C5 | Usage quotidien : sauvegardes, centre de contrôle, entretien, noyau, performance, accès distant | [#176](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/176) |
| C6 | Bureau et applications | [#177](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/177) |
| C7 | Virtualisation | [#178](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/178) |
| C8 | Développement et référence : CI, laboratoire, provenance, inventaire, glossaire, feuille de route | [#179](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/179) |
| C9 | Audit transversal, contrôles stricts, ce compte rendu | PR de ce chantier |

## Défauts du code trouvés en relisant la documentation

Relire chaque guide contre le code a révélé des défauts réels, corrigés dans les mêmes PR, avec un test de régression :

| Défaut | Effet | Correction |
|---|---|---|
| `installer/lib/verify-media.sh` passait à `gpgv` un trousseau sans chemin | `--keyring fedora45.gpg` échouait sur un média valide | chemin relatif forcé ; `tests/test_fedora_media_behavior.sh` (C4) |
| `application-usage-doctor` et `manifests/application-runtime-contract.tsv` exigeaient ONLYOFFICE, retiré du manifeste | la Gate 3 aurait échoué | exigence retirée ; `tests/test_professional_apps_contract.sh` vérifie chaque Flatpak exigé (C6) |
| le precheck de veille renvoyait un `1` brut sans message | blocage incompréhensible sur un noyau sans état de veille | code 20 et message explicite (C2) |
| `data-storage-doctor` contrôlait `IA/Openclaw` sans l'afficher | message de réussite incomplet | message corrigé (C5) |

Pendant la même période, la PR [#172](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/172) a contourné, avec vérification de signature, un refus de dnf5 5.4.6 qui bloquait l'installation de RPM Fusion.

## Erreurs de documentation corrigées

Les plus importantes, celles qui auraient pu tromper l'opérateur :

- la sauvegarde pré-APPLY était décrite comme contenant les données de l'utilisateur ; c'est un point de retour du système, sans `/data` (C5) ;
- le README clonait `main` au lieu du commit audité exigé par le contrôle Live (C2) ;
- plusieurs pages décrivaient encore le profil Fedora 45 comme `pending` et les RPM GNOME 51 comme absents des dépôts stables (C1, C4, C5) ;
- l'inventaire logiciel avait dérivé des manifests : paquets manquants, un paquet jamais installé (C8) ;
- le laboratoire présentait le correctif d'arrêt de DING comme réservé à la VM, alors que la production l'applique (C8).

## Ce que les contrôles garantissent désormais

`tests/test_docs_integrity.py` bloque, sans liste d'exceptions :

- liens et ancres cassés, guide inaccessible depuis le README ;
- commande `./control.sh` inconnue du code, chemin du dépôt inexistant ;
- guide sans bloc de métadonnées, date invalide ou future, vérification antérieure à la dernière mise à jour ;
- bloc Mermaid, schéma sans sa paire, export sans fond opaque, titre ou description ;
- inventaire de l'hôte différent des manifests ;
- fichier suivi en fins de ligne CRLF.

`tests/test_docs_integrity_behavior.py` prouve chaque règle sur des copies du dépôt (19 cas). Aucun contrôle ne juge la formulation : la relecture reste humaine.

## Parcours de lecture

Évaluation heuristique, en nombre de pages depuis le README :

| Lecteur | Besoin | Parcours | Pages |
|---|---|---|---|
| Visiteur | comprendre le projet | README → architecture | 2 |
| Propriétaire | installer le PC | README → contrôle Live → guide d'installation | 3 |
| Propriétaire | résoudre un problème | README → dépannage (tableau d'entrée) → section | 2 |
| Propriétaire | savoir où en est le projet | README (état réel) → feuille de route | 2 |
| Contributeur | proposer un changement | README → guide du contributeur → CI | 3 |

Chaque guide figure dans le portail `docs/README.md` et reçoit au moins deux liens d'autres pages.

## Ce qui reste

- **Matériel** : tous les guides portent `matériel : non vérifié`. La mention changera guide par guide après la Gate 3 sur le PC.
- **Captures** : le README montre une maquette du bureau ; les vraies captures viendront après la qualification.
- **Relecture continue** : un guide modifié doit voir sa date de vérification mise à jour, ce que le contrôle impose désormais.
