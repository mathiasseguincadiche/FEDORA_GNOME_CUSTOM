# Audit du moteur et conformité au besoin de Mathias

Base examinée : `85a0adf` (main, version 0.16.0). Audit du 27 septembre 2026.
Ce document décrit les preuves disponibles, pas une certification du poste.

## Verdict

L'analyse de Claude identifie correctement la duplication des références, le
manque de couverture du parcours d'installation et la prédominance des contrats
textuels. Elle ne suffit pas à affirmer que la sécurité est partout fail-closed.
Des faux succès supplémentaires ont été reproduits dans le moteur et les sondes.

Un dry-run ne constitue pas une installation de bout en bout. La CI en conteneur
ne peut pas qualifier UEFI, GNOME connecté, la B580, les T705 ni la veille physique.
L'absence de preuve dans le dépôt ne démontre pas non plus qu'aucun opérateur n'a
jamais effectué une installation hors dépôt.

Mesures sur cette révision : 72 modules, 58 scripts de tests, 869 lignes dans
`lib/control_center.sh`, 70 documents Markdown sous `docs/` (archives et ADR inclus).
Les décomptes de lignes Bash/grep dépendent des fichiers et commentaires inclus ;
ils ne mesurent pas directement la couverture ni le taux de défauts.

## Corrections de cette branche

| Défaut reproduit | Correction et preuve |
| --- | --- |
| `if fonction` neutralisait `set -e` dans les phases | Un processus Bash strict par module ; erreurs injectées en source/precheck/plan/apply/postcheck, code 37 conservé et suite non exécutée. |
| `exit 0` prématuré pouvait ressembler à une réussite | Le runner exige d'atteindre explicitement la fin des quatre phases. |
| Aucun verrou d'installation | Verrou par utilisateur, commun aux clones, pris avant initialisation des logs ; deuxième lancement refusé. |
| Échec du premier module masquant le reste | `./install.sh --dry-run --collect-all` visite tout le catalogue ; aucun justificatif d'APPLY n'est émis dans ce mode. |
| Manifest de paquets absent assimilé à une liste vide | Erreur explicite avant DNF ; cas fichier absent/vide/valide et échec DNF testés. |
| Journaux CPU/NVMe : erreurs de lecture ou SIGPIPE assimilés à une absence d'erreur | Lecture complète et retour vérifié avant recherche ; erreurs en tête d'un gros journal et journal indisponible testés. |
| Vérification GNOME trouvant « 50 » n'importe où dans le JSON | Validation des champs `uuid` et `shell-version`, indépendante du formatage. |
| Quatre installateurs et références dupliquées | Un installateur partagé et `config/gnome-extensions.lock`, lu par le moteur et la CI. Les overrides locaux de ces constantes sont refusés ; le lock participe à l'empreinte de configuration. |
| Restauration explicite hors zone de staging encore possible | Restriction à l'arbre configuré après résolution des chemins et liens symboliques ; sorties par `..` et symlinks testées. |
| Collisions possibles d'identifiants de logs à la seconde | Ajout du PID à l'identifiant par défaut ; identifiant explicite CI conservé. |

La CI `fedora-installer-audit.yml` exige les 72 entrées et interdit les erreurs
bootstrap/source/contrat/plan/apply. Les blocages precheck/postcheck matériels sont
conservés. Le PASS du job signifie « parcours de diagnostic vérifié », jamais
« installation matérielle réussie ». Les tests de comportement restent nécessaires
pour exercer les branches APPLY qui ne sont pas exécutées en dry-run.

## Exigences utilisateur encore non satisfaites

- **Aucun chiffrement, sauvegardes comprises** : confirmé explicitement le 27/09.
  La version actuelle utilise encore Restic, donc elle n'est pas conforme à ce
  besoin. Un mot de passe vide ne supprime pas le chiffrement Restic. La migration
  vers un moteur non chiffré doit couvrir ensemble pré-APPLY, sauvegarde quotidienne,
  rétention, restauration, runtime systemd autonome et vérification des preuves.
  Borg 1.x `--encryption=none` est une option, pas une migration déjà réalisée.
  Ne pas désactiver simplement les garde-fous pour rendre l'installation verte.
- **BIOS 1.A66 minimum, versions ultérieures admises** : aucune égalité stricte
  n'est à imposer. Le code actuel inventorie version/date mais ne démontre pas le
  respect du minimum. Éviter un tri lexical improvisé des versions MSI ; définir
  les formats DMI et l'ordre des révisions à partir des versions constructeur.
  Après mise à jour du BIOS, refaire les preuves matérielles liées au fingerprint.
- **Qualification réelle** : ni installation complète sur le poste, ni Gate 3
  physique effectuée par cet audit. Les tests GNOME simulés ne prouvent pas le
  confort, le 240 Hz, l'OLED ou la stabilité des reprises.

## Ordre de finalisation

1. Terminer et tester la sauvegarde sans chiffrement sur des données temporaires,
   y compris restauration après perte du disque système, panne et cible absente.
2. Formaliser puis tester la politique de minimum BIOS sans bloquer les mises à jour.
3. Valider une session GNOME réelle (Gate 2), puis réaliser sur le poste sauvegardé
   l'APPLY, le redémarrage, une seconde exécution pour contrôler l'idempotence et
   les scénarios d'échec/reprise. Conserver les rapports avec le commit exact.
4. Réaliser la Gate 3 sur B580/T705/réseaux/audio/veille et seulement alors annoncer
   le profil qualifié. Une migration Ansible est un chantier ultérieur, pas une
   solution automatique aux erreurs de logique ou au manque de preuves.
