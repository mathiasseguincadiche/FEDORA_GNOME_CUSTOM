# Contribuer à Fedora 44 Golden Workstation

Merci de préserver l'objectif principal du dépôt : une Fedora 44 / GNOME 50 **stable, reproductible, mesurée, récupérable et adaptée au matériel cible**.

## Avant de modifier le projet

Lire en priorité :

- [`README.md`](README.md) ;
- [`docs/CAHIER_DES_CHARGES.md`](docs/CAHIER_DES_CHARGES.md) ;
- [`docs/GOLDEN_WORKSTATION.md`](docs/GOLDEN_WORKSTATION.md) ;
- [`docs/EXECUTION_CONTRACT.md`](docs/EXECUTION_CONTRACT.md) ;
- [`docs/adr/README.md`](docs/adr/README.md).

La source de vérité est :

```text
code + config + tests CI
        ↓
document normatif courant
        ↓
document historique / release note
```

Une contradiction documentation/code est un bug.

## Principes de contribution

1. **Ne pas affaiblir les garde-fous** : bare-metal, dry-run, backup pré-APPLY, SELinux, firewalld, KVM fail-closed et vérifications de provenance restent obligatoires.
2. **Ne pas introduire de tuning global non mesuré** : pas de `force_probe`, Mesa git/COPR, kernel gaming tiers ou `sysctl` global sans décision d'architecture explicite.
3. **Réutiliser les moteurs existants** : `control.sh` reste une façade ; la logique métier appartient à `install.sh`, `scripts/`, `diagnostics/` et `lib/`.
4. **Préserver la séparation des environnements** : WSL2, VirtualBox et CI ne doivent jamais être confondus avec le bare-metal.
5. **Documenter les changements opérateur** : toute nouvelle commande publique ou nouvelle contrainte Golden doit apparaître dans la documentation correspondante.
6. **Ajouter ou renforcer un contrat de test** lorsqu'un invariant nouveau est introduit.

## Workflow recommandé

```bash
git checkout main
git pull --ff-only
git checkout -b type/description-courte
```

Effectuer des commits lisibles puis ouvrir une pull request vers `main`.

Le dépôt privilégie des PR focalisées : un objectif clair, un diff cohérent, aucune refonte sans lien avec le problème traité.

## Vérifications locales

Au minimum :

```bash
bash -n control.sh install.sh diagnostic.sh
bash tests/test_workstation_control_center_contract.sh
bash tests/test_documentation_contract.sh
```

Pour un changement plus large, exécuter les contrats concernés dans `tests/`.

La CI GitHub reste l'autorité avant fusion :

- Tests ;
- Shell quality ;
- Architecture non-regression ;
- Fedora 44 package preflight ;
- Fedora 44 desktop integration pretest ;
- Fedora 44 host integration pretest ;
- Fedora 44 gaming pretest lorsque le périmètre le déclenche.

## Shell

- Bash avec `set -Eeuo pipefail` lorsque le script le permet ;
- code compatible ShellCheck ;
- messages opérateur courts et explicites ;
- aucune mutation cachée derrière un diagnostic ;
- `NO_COLOR=1` doit rester utilisable pour les surfaces opérateur.

## Documentation

Le README racine doit rester une **vitrine et un guide d'entrée**, pas un duplicata du cahier des charges.

Les détails doivent vivre dans `docs/`. Les liens Markdown locaux doivent rester valides.

## Hardware et Gate 3

Un résultat CI ne constitue jamais une preuve physique.

Tout changement touchant kernel, firmware, drivers, stockage, affichage, KVM, Gaming ou suspend/resume peut nécessiter une nouvelle preuve Gate 3 et rendre une certification précédente `STALE`.

## Pull request

La PR doit préciser :

- le problème ou l'objectif ;
- ce qui change ;
- les invariants impactés ;
- les tests exécutés ;
- les éventuelles preuves runtime encore différées au bare-metal.

Le template `.github/pull_request_template.md` fournit la checklist minimale.

## Sécurité

Ne publier aucun secret, mot de passe Restic, token, clé privée ou média propriétaire.

Pour un problème de sécurité, suivre [`SECURITY.md`](SECURITY.md) plutôt qu'une issue publique.
