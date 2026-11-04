# Contribuer à Fedora Golden Workstation

L'objectif du dépôt : une Fedora 45 / GNOME 51 **stable, reproductible, mesurée, récupérable et adaptée au matériel cible**.

La source de vérité est le **code, la configuration et les tests**. Viennent ensuite les guides courants, puis l'historique (`docs/history/`, `CHANGELOG.md`, ADR remplacées). Une contradiction entre un guide et le code est un bug. Avant une modification structurante, lire l'[architecture](docs/ARCHITECTURE.md), le [contrat d'exécution](docs/ARCHITECTURE.md#contrat-dexécution) et les [ADR](docs/adr/README.md).

## Principes

1. **Ne pas affaiblir les garde-fous** : matériel physique, dry-run, sauvegarde pré-APPLY, SELinux, firewalld, réseau KVM fail-closed et vérifications de provenance restent obligatoires.
2. **Pas de réglage global non mesuré** : pas de `force_probe`, Mesa git/COPR, noyau gaming tiers ou `sysctl` global sans décision d'architecture explicite (ADR).
3. **Réutiliser les moteurs** : `control.sh` reste une façade ; la logique appartient à `install.sh`, `scripts/`, `diagnostics/` et `lib/`.
4. **Séparer les environnements** : la CI teste le logiciel, le Live USB observe le PC avant installation, la Gate 3 qualifie le système installé.
5. **Tester le comportement** : un invariant nouveau s'accompagne d'un test qui exécute le code (fixtures, faux binaires), pas d'un `grep` qui recopie une chaîne du code ou une phrase de la doc.

## Où vit chaque parcours

| Parcours | Code | Guide | Validation |
|---|---|---|---|
| Point d'entrée | `control.sh`, `lib/control_center.sh` | [Centre de contrôle](docs/CONTROL_CENTER.md) | `tests/test_workstation_control_center_contract.sh` |
| Live USB | `diagnostics/live-preflight.sh`, `scripts/validation/` | [Contrôle Live](docs/FEDORA45_LIVE_PREFLIGHT.md) | `.github/workflows/live-preflight.yml` |
| Installation | `install.sh`, `installer/`, `lib/apply_gate.sh` | [Installation](docs/INSTALLATION_GUIDE.md) | `.github/workflows/fedora-installer-audit.yml` |
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
- Une commande documentée existe, avec ses paramètres obligatoires ; une procédure dit comment reconnaître le succès et quand **ne pas continuer**.
- Distinguer lecture seule, dry-run, mutation protégée et opération manuelle ou destructive. Une commande destructive n'est jamais noyée dans une séquence sans précondition.
- Les valeurs réseau, stockage et VM viennent de `config/*.conf` ; les citer depuis la config plutôt que les recopier.
- Ne jamais proposer de désactiver SELinux, firewalld ou un garde-fou pour faire passer un test.
- « Code prêt » et « Golden runtime-certified » restent distincts jusqu'à la Gate 3.
- Les schémas ne montrent aucun raccourci vers `install.sh --apply` et ne confondent jamais CI, Live et Gate 3.
- Une maquette est étiquetée comme telle ; une preuve physique porte son contexte.

### Statuts

Toute affirmation sur ce que fait le projet porte l'un de ces statuts, explicitement ou par sa formulation :

| Statut | Signification | Preuve attendue |
|---|---|---|
| Prévu | Décidé, pas commencé | Aucune |
| En cours | Commencé, non terminé | Référence au travail (branche, PR) |
| Réalisé | Présent dans le code ou la configuration | Fichier identifiable |
| Vérifié | Contrôlé par une méthode traçable | Date, méthode, environnement et résultat |
| Non vérifié | Contrôle non fait ou impossible | Ce qui n'a pas été contrôlé, et pourquoi |

« Vérifié par la CI » et « vérifié sur le matériel » ne se confondent jamais : seule la Gate 3 vérifie le PC. Une sortie de commande donnée en exemple est signalée comme telle ; elle n'est jamais présentée comme un résultat observé.

### Ton et vocabulaire

- **Registre** : infinitif impersonnel pour les consignes (« Lancer… », « Vérifier… »), phrases complètes pour les explications. Ni tutoiement, ni vouvoiement.
- **Une idée par paragraphe.** Une énumération devient une liste, une comparaison un tableau.
- **Gras réservé** aux avertissements et à la première occurrence d'un terme défini.
- **Pas de qualificatif non démontré** (« robuste », « sécurisé », « complet ») : décrire ce qui est contrôlé et comment.
- **Lexique** : les commandes, options, noms de fichiers et noms de produits restent en version originale (`doctor`, `APPLY`, `Gate 3`, Borg). Les titres et les notions sont en français ; le terme anglais d'usage figure entre parenthèses à sa première occurrence. Un terme garde le même sens dans tout le dépôt ; le [glossaire](docs/GLOSSARY.md) fait foi.

### Métadonnées des guides

Chaque guide de `docs/` (hors `docs/adr/` et `docs/history/`) commence, sous son titre, par ce bloc :

```markdown
> Mise à jour : AAAA-MM-JJ · Responsable : @mathiasseguincadiche
> Dernière vérification : AAAA-MM-JJ — méthode et périmètre — matériel : non vérifié
```

« Mise à jour » est la date du dernier changement de fond. « Dernière vérification » dit comment le contenu a été contrôlé (par exemple « relecture contre le code de `main` ») et sur quel périmètre. La mention `matériel` passe à `vérifié (Gate 3, AAAA-MM-JJ)` seulement après une preuve physique. Le bloc ne recopie pas le numéro de version du projet.

### Schémas

- Un schéma n'existe que s'il répond à une question du lecteur qu'un tableau ou une liste ne règle pas aussi bien.
- Chaque schéma est une paire de fichiers de même nom de base dans `docs/assets/diagrams/` : la source éditable `<nom>.drawio` (format diagrams.net, XML non compressé) et l'export `<nom>.svg`.
- Le SVG a un fond opaque, un `<title>` et une `<desc>`. Il reste lisible dans les thèmes clair et sombre de GitHub et ne porte aucune information par la couleur seule.
- Dans la page, l'image est suivie d'une description textuelle des relations importantes et d'un lien vers sa source `.drawio`.
- Mermaid n'est pas utilisé.

### Contrôles

`tests/test_docs_integrity.py` vérifie les liens, l'accessibilité de chaque page depuis le README, les commandes `./control.sh` citées et les chemins du dépôt cités. Il contrôle aussi la forme du bloc de métadonnées, les paires de schémas `.drawio` / `.svg`, l'absence de Mermaid, et que l'inventaire logiciel de l'hôte reproduit exactement les manifests de `manifests/`. Tous les guides ont été repris : les listes de migration du test sont vides. Le test ne vérifie jamais la formulation : la relecture reste nécessaire.

## Shell

`set -Eeuo pipefail` quand le script le permet, code propre au ShellCheck de la CI (0.9), messages courts, aucune mutation cachée derrière un diagnostic, `NO_COLOR=1` utilisable.

## Matériel et Gate 3

Un résultat CI ne prouve rien sur le matériel. Toute modification du noyau, du firmware, des pilotes, du stockage, de l'affichage, de KVM, du Gaming ou de la veille peut demander une nouvelle preuve Gate 3 et rendre une certification `STALE`.

## Sécurité

Ne publier aucun secret, mot de passe, jeton, clé privée ni média propriétaire. Pour une vulnérabilité, suivre [`SECURITY.md`](SECURITY.md) plutôt qu'une issue publique.
