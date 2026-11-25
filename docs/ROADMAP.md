# Feuille de route

> Mise à jour : 2026-11-25 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-25 — fusions et résultats de PR confirmés, préversion préparée sans certification physique — matériel : non vérifié

Cette page dit où en est le projet et ce qui vient ensuite. Elle ne promet pas de date : chaque étape commence quand la précédente est prouvée. L'état détaillé, preuve par preuve, est dans le [README](../README.md#état-réel).

## Où en est le projet

| Étape | Statut | Preuve |
|---|---|---|
| Profil Fedora 45 / GNOME 51 promu `ready` | Vérifié le 2026-11-03 | média final 1.4 authentifié, RPM stables ([fiche Fedora 45](FEDORA45_PRIMARY.md)) |
| Préversions 0.24.0 et 0.24.1 publiées | Réalisé | releases `v0.24.0-rc.1` et `v0.24.1-rc.1`, publiées par `release.yml` après la CI verte du commit exact |
| Refonte de la documentation | Réalisé | chantiers C1 à C9 ([compte rendu](history/DOCUMENTATION_OVERHAUL_2026-11.md)) |
| Actualisation Rocky 10.3 et GNOME 51 | Intégré | PR [#229](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/229) à [#233](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/233) ; tests CI réussis |
| Protections APPLY et sauvegarde | Intégré | PR [#234](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/234) à [#237](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/237) ; tests CI réussis |
| Modernisation GitHub Actions / Dependabot | Intégré | PR [#238](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/238) et [#239](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/239) ; contrôles post-fusion à consulter |
| Revue documentaire et schémas | Intégré | PR [#240](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/240) ; intégrité documentaire et 14 paires Draw.io/SVG reproductibles ; recette visuelle native complète non exécutée |
| Préversion 0.25.0 | Candidate | manifeste de release préparé ; publication soumise à la CI du commit exact de `main` |
| Contrôle du PC depuis le Live USB | Prévu | [contrôle Live](FEDORA45_LIVE_PREFLIGHT.md) |
| Installation, APPLY et Gate 3 sur le PC | Prévu | [guide d'installation](INSTALLATION_GUIDE.md), [qualification](QUALIFICATION.md) |
| Version 1.0 | Prévu | Gate 3 réussie puis période d'usage réel stable |

## Prochaines étapes, dans l'ordre

1. **Préparer la préversion suivante**, après revue documentaire et contrôles CI du commit exact, sans annoncer une certification physique.
2. **Contrôler le PC depuis le Live USB**, au commit publié : matériel, pilotes, les deux T705, sans aucune écriture sur les SSD internes. Exporter le rapport `PREINSTALL_ONLY` et sa somme SHA-256.
3. **Examiner les résultats et décider** : revue du rapport Gate 2, correction des échecs et des incertitudes importantes, puis **GO humain explicite** avant tout effacement du SSD système.
4. **Installer et qualifier** après accord : installation Fedora 45, import du compte rendu Live, baseline, dry-run, sauvegarde pré-APPLY, APPLY, redémarrage, Gate 3.
5. **Corriger ce que la Gate 3 révèle**, par petites PR, puis requalifier.
6. **Utiliser le poste** une période significative avant de déclarer la 1.0.

Aucune nouvelle fonctionnalité n'est ajoutée avant la Gate 3 ([décisions du propriétaire](ARCHITECTURE.md#décisions-du-propriétaire)).

## Points Fedora 45 à observer sur le PC

Ces nouveautés de Fedora 45 ne demandent aucun réglage a priori. Elles sont à observer pendant la qualification, et à corriger seulement sur preuve :

| Domaine | À vérifier |
|---|---|
| RPM 6.1 | les dépôts fournis par paquets ne sont pas supposés vivre uniquement dans `/etc/yum.repos.d` |
| Secrets GNOME | trousseau, `libsecret`, ouverture de session, portails ; `gnome-keyring` reste en place tant qu'une migration n'a pas prouvé l'équivalence |
| NetworkManager et IPv6 | DNS, IPv4/IPv6 et réseau NAT des VM ; IPv6 n'est jamais désactivé pour masquer un échec |
| GNOME 51 | multi-écran, 240 Hz, VRR et reprise après veille sur la B580 |
| Redémarrage avec session ouverte | cas observé dans le laboratoire QEMU, à qualifier sur le PC ([laboratoire](FEDORA_GNOME_CI_LAB.md#démarrage-et-redémarrage)) |

Références : [ChangeSet Fedora 45](https://fedoraproject.org/wiki/Releases/45/ChangeSet), [GNOME 51](https://release.gnome.org/51/).

## Historique

La feuille de route d'octobre 2026, écrite avant la sortie de Fedora 45, est archivée : [feuille de route Fedora 45, octobre 2026](history/ROADMAP_FEDORA45_2026.md). Les versions publiées sont dans le [CHANGELOG](../CHANGELOG.md).
