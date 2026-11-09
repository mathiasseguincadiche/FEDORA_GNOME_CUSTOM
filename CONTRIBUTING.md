# Contribuer à Fedora Golden Workstation

L'objectif du dépôt : une Fedora 45 / GNOME 51 **stable, reproductible, mesurée, récupérable et adaptée au matériel cible**.

La source de vérité est le **code, la configuration et les tests**. Viennent ensuite les guides courants, puis l'historique (`docs/history/`, `CHANGELOG.md`, ADR remplacées). Une contradiction entre un guide et le code est un bug. Avant une modification structurante, lire l'[architecture](docs/ARCHITECTURE.md), le [contrat d'exécution](docs/ARCHITECTURE.md#contrat-dexécution) et les [ADR](docs/adr/README.md).

## Principes

1. **Ne pas affaiblir les garde-fous** : matériel physique, dry-run, sauvegarde pré-APPLY, SELinux, firewalld, réseau KVM fermé par défaut et vérifications de provenance restent obligatoires.
2. **Pas de réglage global non mesuré** : pas de `force_probe`, Mesa git/COPR, noyau gaming tiers ou `sysctl` global sans décision d'architecture explicite (ADR).
3. **Réutiliser les moteurs** : `control.sh` reste une façade ; la logique appartient à `install.sh`, `scripts/`, `diagnostics/` et `lib/`.
4. **Séparer les environnements** : la CI teste le logiciel, la Gate 2 observe le PC depuis le Live USB, la Gate 3 qualifie le système installé. Après la Gate 2, le propriétaire examine le compte rendu et autorise explicitement l'installation ; un `GO` logiciel ne vaut pas cet accord.
5. **Tester le comportement** : un invariant nouveau s'accompagne d'un test qui exécute le code (fixtures, faux binaires), pas d'un `grep` qui recopie une chaîne du code ou une phrase de la doc.

## Où vit chaque parcours

| Parcours | Code | Guide | Validation |
|---|---|---|---|
| Point d'entrée | `control.sh`, `lib/control_center.sh` | [Centre de contrôle](docs/CONTROL_CENTER.md) | `tests/test_workstation_control_center_contract.sh` |
| Live USB | `diagnostics/live-preflight.sh`, `scripts/validation/` | [Contrôle Live](docs/FEDORA45_LIVE_PREFLIGHT.md) | `.github/workflows/live-preflight.yml` |
| Installation | `install.sh`, `installer/`, `lib/apply_gate.sh` | [Installation](docs/INSTALLATION_GUIDE.md) | job `installer-audit` de `.github/workflows/tests.yml` (PR) ; `.github/workflows/fedora-installer-audit.yml` (`main`) |
| Promotion Fedora 45 | `scripts/development/promote-fedora45.py`, `profiles/fedora45/` | [Fiche Fedora 45](docs/FEDORA45_PRIMARY.md) | `tests/test_promote_fedora45_behavior.sh` |
| Qualification | `scripts/validation/`, `diagnostics/final-certification` | [Qualification](docs/QUALIFICATION.md) | `tests/test_three_gate_validation_contract.sh` |
| GNOME | `modules/gnome/`, `config/gnome-extensions.lock` | [GNOME](docs/GNOME.md) | tests d'extensions et laboratoire GNOME |
| Noyau | `lib/kernel_lifecycle.sh`, `scripts/kernel/` | [Linux amont](docs/UPSTREAM_LINUX.md) | `tests/test_kernel_lifecycle_behavior.sh` |
| Sauvegarde | `lib/backup_runtime.sh`, `scripts/backup/` | [Sauvegardes](docs/BACKUP_RESTORE.md) | `tests/test_borg_roundtrip.sh` (vrai Borg) |
| KVM et Rocky | `scripts/kvm/`, `guest/rocky-devops/` | [Démarrage KVM](docs/KVM_QUICKSTART.md) | laboratoire Rocky Linux |
| Accès distant | `lib/remote_access.sh`, `modules/remote/` | [Accès distant](docs/REMOTE_ACCESS.md) | `tests/test_remote_access_contract.sh` |

## Workflow

```bash
git checkout main
git pull --ff-only
git checkout -b type/description-courte
```

Une PR = un objectif clair et un diff cohérent. Elle précise le problème, ce qui change, les invariants touchés, les tests lancés et les preuves physiques encore à faire (modèle : `.github/pull_request_template.md`).

Vérifications locales minimales :

```bash
bash -n control.sh install.sh diagnostic.sh
bash tests/test_workstation_control_center_contract.sh
python3 -B tests/test_docs_integrity.py
```

Pour un changement plus large, lancer les tests du domaine dans `tests/`. La CI GitHub reste l'autorité.

## Branche `main` et CI

`main` est protégée par un ruleset : pull request obligatoire, pas de force-push ni de suppression, branche à jour avant fusion. Contextes obligatoires : **contracts**, **shellcheck**, **guards**, **packages**, **packages-and-integration**, **nautilus-ptyxis**. `contracts` dépend notamment de `installer-audit`, `borg-fedora` et du laboratoire Rocky Linux : leur échec ou absence le bloque. Un contexte obligatoire doit être produit sur **chaque** PR (d'où l'absence de filtre `paths:` sur `nautilus-ptyxis`). `scripts/development/check-main-protection.sh` vérifie l'état public de la protection sans le modifier ; la doc seule ne prouve pas qu'un réglage est actif.

Les contrôles d'une PR portent sur un autre SHA que le commit de fusion : **relire aussi les checks du `push` sur `main`** après fusion, et corriger par une nouvelle PR si besoin. Fusion par merge commit (pas de squash ni de rebase), suppression automatique de la branche. Une restriction de registre ou de dépôt externe se corrige à la source, jamais en désactivant le test. Lecture des résultats : [CI](docs/CI_VALIDATION.md).

## Versions et release

Toute modification fonctionnelle fusionnée met à jour `VERSION`, `CHANGELOG.md`, et `README.md` si le contrat utilisateur change. Les guides ne recopient pas le numéro de version.

`.github/release-manifest.env` décrit la release candidate. Le workflow `release.yml` attend le succès des workflows Tests, Shell quality, Architecture non-regression, Fedora package preflight, host integration, desktop integration, installer audit et Security scanning (CodeQL, Gitleaks) sur le **même SHA** poussé sur `main`, vérifie que le tag correspond à `VERSION`, puis crée la prerelease. Il refuse de déplacer un tag existant.

## Écrire la documentation

Cette section est la source de vérité des conventions de rédaction. Elle s'applique aux guides courants : README, `docs/` hors `docs/adr/` et `docs/history/`. Les ADR, l'historique et le `CHANGELOG.md` sont des archives : leur formulation d'origine est conservée.

### Contenu

- Le `README.md` racine est une vitrine ; les détails vivent dans `docs/`, avec un guide par sujet. Un détail déjà écrit ailleurs se lie, il ne se recopie pas.
- Une commande documentée existe, avec ses paramètres obligatoires ; une procédure dit depuis quel environnement et quel répertoire la lancer, ce qu'elle modifie, comment reconnaître le succès et quand **ne pas continuer**.
- Distinguer lecture seule, dry-run, mutation protégée et opération manuelle ou destructive. Une commande destructive n'est jamais noyée dans une séquence sans précondition.
- Les valeurs réseau, stockage et VM viennent de `config/*.conf` ; les citer depuis la config plutôt que les recopier.
- Ne jamais proposer de désactiver SELinux, firewalld ou un garde-fou pour faire passer un test.
- « Code prêt » et « Golden runtime-certified » restent distincts jusqu'à la Gate 3.
- Les schémas ne montrent aucun raccourci vers `install.sh --apply` et ne confondent jamais CI, Live et Gate 3.
- Une maquette est étiquetée comme telle ; une preuve physique porte son contexte.
- La Gate 2 et la Gate 3 conservent leurs rôles. Le passage **Live USB → installation** mentionne toujours l'export et la revue des résultats, puis l'autorisation humaine explicite, avant de toucher au SSD.

### Expliquer pour transmettre

Un guide doit aider à comprendre une opération, pas simplement l'exécuter. Pour un mécanisme nouveau ou risqué, présenter dans un ordre naturel :

1. **Le besoin** : quel problème concret est résolu et pourquoi il importe ici.
2. **Le principe** : fonctionnement expliqué avec un vocabulaire accessible, en définissant les termes techniques à leur première apparition.
3. **Le choix du projet** : quel composant ou mécanisme répond au besoin, et pourquoi.
4. **La manipulation** : prérequis, précontrôles, emplacement de lancement, commandes et effets possibles.
5. **La validation** : résultat observable, portée de la preuve et limites.
6. **Le diagnostic** : premier symptôme, cause à établir, condition d'arrêt et retour arrière sûr.

Adapter la profondeur au risque : un danger de formatage ou de perte de données demande une procédure détaillée ; un inventaire d'options peut rester direct. Le README oriente et motive, le guide d'installation fixe l'ordre, la qualification définit les critères et le centre de contrôle fait foi pour les commandes. **Ne pas recopier les mêmes étapes dans chaque page.**

Pour la relecture, vérifier trois profils de lecteur : une personne découvrant Linux, un utilisateur qui veut accomplir une tâche précise et un ingénieur qui cherche la source du comportement. Les informations doivent être faciles à trouver pour les trois, sans promettre de contrôle physique non effectué.

### Statuts

Toute affirmation sur ce que fait le projet porte l'un de ces statuts, explicitement ou par sa formulation :

| Statut | Signification | Preuve attendue |
|---|---|---|
| Prévu | Décidé, pas commencé | Aucune |
| En cours | Commencé, non terminé | Référence au travail (branche, PR) |
| Réalisé | Présent dans le code ou la configuration | Fichier identifiable |
| Abandonné | Prévu ou commencé, puis retiré | Raison et date, si elles sont connues |
| Vérifié | Contrôlé par une méthode traçable | Date, méthode, environnement et résultat |
| Échec constaté | Contrôlé, et le résultat attendu n'est pas obtenu | Comme « Vérifié », avec le résultat réel |
| Non vérifié | Contrôle non fait ou impossible | Ce qui n'a pas été contrôlé, et pourquoi |

Les trois premiers statuts et « Abandonné » disent où en est le travail ; « Vérifié », « Échec constaté » et « Non vérifié » disent s'il a été contrôlé. Un élément porte souvent les deux, par exemple « Réalisé — Non vérifié » : la présence du code ne prouve pas qu'il fonctionne.

« Vérifié par la CI » et « vérifié sur le matériel » ne se confondent jamais : seule la Gate 3 vérifie le PC. Une sortie de commande donnée en exemple est signalée comme telle ; elle n'est jamais présentée comme un résultat observé.

**Portée d'une preuve.** Un « Vérifié » vaut pour le commit, l'environnement et le périmètre contrôlés, et les nomme (« au commit `0007d97`, en VM jetable »). Quand l'élément change ensuite, son contrôle redevient « Non vérifié » jusqu'au suivant. Un échec corrigé reste consigné, suivi de la nouvelle validation.

### Ton et vocabulaire

- **Registre** : infinitif impersonnel pour les consignes (« Lancer… », « Vérifier… »), phrases complètes pour les explications. Ni tutoiement, ni vouvoiement.
- **Une idée par paragraphe.** Une énumération devient une liste, une comparaison un tableau.
- **Le besoin avant le mécanisme.** Une section importante s'ouvre par deux ou trois phrases qui disent quel problème elle règle et ce qu'elle permet ; le détail vient ensuite. Un terme technique s'explique dans la phrase qui l'introduit. Un contrôle dit ce qu'il garantit et ce qu'il ne prouve pas.
- **Gras de repère**, un à trois par paragraphe ou par puce : un avertissement, un terme défini à sa première occurrence, l'intention d'une étape ou sa conclusion (« **Réussite :** »). Jamais une phrase entière ni un mot mis en valeur sans raison.
- **Pas de qualificatif non démontré** (« robuste », « sécurisé », « complet ») : décrire ce qui est contrôlé et comment.
- **Lexique** : les commandes, options, noms de fichiers et noms de produits restent en version originale (`doctor`, `APPLY`, `Gate 3`, Borg). Les titres et les notions sont en français ; le terme anglais d'usage figure entre parenthèses à sa première occurrence. Un terme garde le même sens dans tout le dépôt ; le [glossaire](docs/GLOSSARY.md) fait foi.
- **Charte des apostrophes** : l'apostrophe droite (`'`) s'emploie partout, dans les guides comme dans le code, pour rester cohérent avec le shell et les recherches ; `tests/test_docs_integrity.py` la contrôle hors archives. Les archives (`docs/adr/`, `docs/history/`, `CHANGELOG.md`) conservent leur formulation d'origine, y compris leurs apostrophes typographiques.

### Révision éditoriale avant une refonte importante

1. **Attribuer un rôle à chaque page.** Le README présente et oriente ; `docs/README.md` est un répertoire ; les guides enseignent ou guident l'action ; les références décrivent le contrat précis. Un même point technique ne doit pas être développé intégralement dans trois pages différentes.
2. **Travailler d'abord sur deux pages pilotes.** Examiner le rendu d'une page d'accueil et d'une procédure représentative avant de généraliser le style. Pour une procédure, conserver le besoin, les prérequis, le contexte d'exécution, le point d'arrêt, la commande, la preuve et la reprise.
3. **Réviser le fond avant les phrases.** Réordonner les idées, supprimer les redites, relier les sections, puis corriger le vocabulaire et la typographie. Aucun raccourcissement ne doit retirer une condition de sécurité.
4. **Privilégier deux vitesses de lecture.** Un débutant doit comprendre le besoin et les termes nouveaux ; un technicien doit localiser sans détour les commandes, les contrats et les limites de validation.
5. **Comparer au code après la réécriture.** Préserver les paramètres, les chemins, les identités matérielles, les Gates et les preuves. Inspecter le rendu GitHub à largeur normale et étroite lorsque les outils le permettent ; une CI verte n'est pas une validation de l'esthétique.

Pour les schémas, valider une vue pilote avant de décliner la même palette et la même hiérarchie sur les sept paires. Préférer les cartes alignées et les flèches lisibles aux parcours en zigzag ; distinguer schémas de présentation et vues techniques détaillées.

### Métadonnées des guides

Le `README.md` racine et chaque guide de `docs/` (hors `docs/adr/` et `docs/history/`) commencent, sous leur titre, par ce bloc :

```markdown
> Mise à jour : AAAA-MM-JJ · Responsable : @mathiasseguincadiche
> Dernière vérification : AAAA-MM-JJ — méthode et périmètre — matériel : non vérifié
```

« Mise à jour » est la date du dernier changement de fond ; modifier un guide sans revérifier son contenu fait échouer le contrôle. « Dernière vérification » dit comment le contenu a été contrôlé (par exemple « relecture contre le code de `main` ») et sur quel périmètre. La mention `matériel` passe à `vérifié (Gate 3, AAAA-MM-JJ)` seulement après une preuve physique. Le bloc ne recopie pas le numéro de version du projet.

### Schémas

- Un schéma n'existe que s'il répond à une question du lecteur qu'un tableau ou une liste ne règle pas aussi bien.
- Chaque schéma est une paire de fichiers de même nom de base dans `docs/assets/diagrams/` : la source éditable `<nom>.drawio` (format diagrams.net, XML non compressé) et l'image `<nom>.svg` affichée par GitHub. Le générateur écrit les deux à partir du même modèle : le `.svg` n'est pas un export de diagrams.net.
- Le SVG a un fond opaque, un `<title>` et une `<desc>`. Il reste lisible dans les thèmes clair et sombre de GitHub et ne porte aucune information par la couleur seule.
- Dans la page, l'image est suivie d'une description textuelle des relations importantes et d'un lien vers sa source `.drawio`.
- Mermaid n'est pas utilisé.
- Les paires sont produites par le [générateur du dépôt](tools/diagrams/README.md), jamais retouchées à la main : `tests/test_diagram_sources.py` échoue si un fichier diffère de ce que produit `tools/diagrams/build.py`.

### Charte graphique

La documentation s'affiche dans le rendu natif de GitHub : le projet ne choisit ni police ni taille de texte. La charte porte donc sur la structure des pages et sur les couleurs des schémas.

**Pages**

- Un seul titre de niveau 1 par page, sans saut de niveau.
- Un tableau compare ; au-delà de quatre colonnes, il défile sur un écran de téléphone : préférer alors une liste ou deux tableaux.
- Un bloc de code annonce son langage (`bash`, `text`, `ini`…) et ne contient que ce qui se copie.
- Une citation (`>`) est réservée au bloc de métadonnées et aux avertissements importants ; pas d'emoji, pas de badge décoratif. Aucun badge statique : le seul badge autorisé est le badge dynamique du workflow `Tests` dans le README, qui reflète un run réel de `main` ; la licence se cite en texte, avec un lien vers `LICENSE`.
- Une image a un texte alternatif qui dit ce qu'elle montre.

**Schémas** — palette « cartes claires », définie dans `tools/diagrams/diagramkit.py`. Chaque couleur a une fonction ; le libellé porte toujours le sens, la couleur ne fait que le renforcer.

| Fonction | Fond | Bordure | Texte sur fond | Bordure sur blanc |
|---|---|---|---|---|
| Élément central (contrôle, décision) | `#EAF2FF` | `#346AC4` | 12,55:1 | 5,24:1 |
| Élément ordinaire | `#FFFFFF` | `#C4D5E8` | 14,14:1 | 1,50:1, cadre décoratif |
| Données et résultats | `#E8F6EF` | `#198263` | 12,70:1 | 4,76:1 |
| Attention | `#FFF3DE` | `#AC731B` | 12,88:1 | 4,02:1 |
| Hors périmètre, manuel (trait pointillé) | `#FFFFFF` | `#7C8A9C` | 14,14:1 | 3,52:1 |
| Groupe | `#FFFFFF` | `#D9E3EF` | titre `#2959B4` : 6,60:1 | 1,30:1, cadre décoratif |

Texte `#1A2C43`, flèches `#547BB4` (4,09:1 sur le fond `#F7F9FC`), police Arial, fond opaque. Contrastes calculés selon WCAG par `tools/diagrams/verify.py`, le 2026-11-06 : les libellés atteignent au moins 4,5:1 et les flèches au moins 3:1. Les cadres ordinaires ou de groupe sous 3:1 ne portent aucune information seuls ; le texte et les titres des zones les identifient.

### Contrôles

`tests/test_docs_integrity.py` vérifie les liens, l'accessibilité de chaque page depuis le README, les commandes `./control.sh` citées, la présence de chaque commande routée dans le [centre de contrôle](docs/CONTROL_CENTER.md) et les chemins du dépôt cités. Il contrôle aussi le bloc de métadonnées de chaque guide (dates valides, jamais futures, vérification jamais antérieure à la mise à jour), les paires de schémas `.drawio` / `.svg`, l'absence de Mermaid, l'inventaire logiciel de l'hôte, qui doit reproduire exactement `manifests/`, et les fins de ligne LF de tous les fichiers suivis. Il contrôle aussi le bloc de métadonnées du `README.md` racine, chaque visuel de `docs/assets/` référencé par au moins une page Markdown (et tout lien vers un visuel existant), l'accessibilité de chaque export SVG hors `docs/assets/diagrams/` (viewBox, titre, description, fond opaque, aucune ressource distante), et l'absence d'apostrophe typographique (U+2019) hors archives. Ces règles s'appliquent sans liste d'exceptions ; `tests/test_docs_integrity_behavior.py` prouve chacune d'elles. Le test ne vérifie jamais la formulation : la relecture reste nécessaire.

Le contrôle structurel vérifie également qu'un guide courant possède exactement un titre `#`, que les niveaux de titres progressent sans saut et que les blocs de code ont un langage et une fermeture. Les titres présents à l'intérieur des blocs de code sont ignorés. Les archives historiques restent hors de ce contrôle ; des tests de comportement couvrent chaque refus et les exemples littéraux.

## Shell

`set -Eeuo pipefail` quand le script le permet, code propre au ShellCheck de la CI (0.9), messages courts, aucune mutation cachée derrière un diagnostic, `NO_COLOR=1` utilisable.

Chaque point d'entrée, doctor, script et bibliothèque commence, juste après le shebang, par un commentaire qui dit son rôle et ce qu'il peut modifier : rien, un rapport dans `reports/`, une preuve dans `state/`, ou le système. Les modules en sont dispensés, car leur fonction `plan` les décrit déjà. `tests/test_structure.sh` refuse un fichier sans ce commentaire. Un commentaire dans le code explique une intention ou une précaution, jamais ce que la ligne dit déjà.

**Langue des commentaires** : l'en-tête de rôle des modules (`modules/`) et des fichiers de `config/` est en français, comme la documentation ; celui des bibliothèques (`lib/`) et des points d'entrée racine (`*.sh`) reste en anglais, héritage du socle. Un fichier ne mélange pas les deux langues dans ses commentaires.

## Matériel et Gate 3

Un résultat CI ne prouve rien sur le matériel. Toute modification du noyau, du firmware, des pilotes, du stockage, de l'affichage, de KVM, du Gaming ou de la veille peut demander une nouvelle preuve Gate 3 et rendre une certification `STALE`.

## Sécurité

Ne publier aucun secret, mot de passe, jeton, clé privée ni média propriétaire. Pour une vulnérabilité, suivre [`SECURITY.md`](SECURITY.md) plutôt qu'une issue publique.
