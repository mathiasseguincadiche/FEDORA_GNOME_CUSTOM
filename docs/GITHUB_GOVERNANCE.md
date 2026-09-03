# GitHub governance — pré-1.0

`main` est une branche de production : aucun changement ne doit contourner la validation automatisée.

## Ruleset attendu sur `main`

Configurer dans GitHub un ruleset ciblant `refs/heads/main` avec :

- pull request obligatoire avant fusion ;
- interdiction des force-push ;
- interdiction de supprimer `main` ;
- branche à jour avant fusion ;
- checks obligatoires : **Tests**, **Shell quality**, **Architecture non-regression**, **Fedora 44 package preflight**, **Fedora 44 host integration pretest**, **Fedora 44 desktop integration pretest** ;
- le workflow Ubuntu 26.04 doit être vert lorsqu'il est déclenché par une modification de la VM, de son bootstrap ou de sa supply-chain.

Tout check configuré comme obligatoire dans le ruleset doit produire un contexte sur **chaque pull request**. En particulier, le job `nautilus-ptyxis` du workflow Fedora 44 desktop integration pretest est volontairement déclenché sans filtre `paths:` sur les pull requests afin qu'une modification non Desktop ne reste jamais bloquée dans l'état `Expected — Waiting for status to be reported`.

Le dépôt contient `scripts/development/check-main-protection.sh` pour vérifier l'état public attendu de la protection. Ce script ne modifie aucun réglage GitHub.

## Discipline de branche et de merge

Les changements fonctionnels ou structurants sont préparés sur une branche dédiée puis proposés par pull request.

Politique de merge du projet :

```text
merge commit : OUI
squash merge : NON
rebase merge : NON
suppression automatique de la branche après merge : OUI
```

Le merge commit est retenu afin de conserver la frontière exacte de chaque PR, son SHA de tête validé et son rattachement à l'historique de revue. Les branches de travail sont jetables et doivent être supprimées automatiquement après fusion.

## Discipline de release

Toute modification fonctionnelle fusionnée dans `main` doit être reflétée dans :

```text
VERSION
CHANGELOG.md
README.md lorsque le contrat utilisateur change
```

La release candidate 0.14.0 est décrite par `.github/release-manifest.env`. Le workflow `.github/workflows/release.yml`, déclenché uniquement après intégration de ce manifeste sur `main`, crée de façon idempotente la prerelease :

```text
v0.14.0-rc.1
```

Le tag est créé sur le SHA exact du push `main` qui introduit le manifeste. Si une release du même nom existe déjà sur un autre SHA, le workflow échoue au lieu de déplacer silencieusement le tag.

Les documents normatifs ne recopient pas inutilement le numéro de release dans leur titre ; ils suivent la version indiquée par `VERSION`. Les anciens numéros restent acceptables dans les release notes et le changelog lorsqu'ils décrivent explicitement l'historique.

## Contrat documentaire

La documentation est traitée comme une partie du produit. La CI doit notamment empêcher :

- commandes documentées qui n'existent plus ;
- contradiction entre profil GNOME et extensions réellement gérées ;
- contradiction entre GNOME core et le manifeste Nautilus dédié ;
- valeurs KVM documentées différentes de `virtualization.conf`/XML ;
- oubli d'une application professionnelle déjà présente dans les manifests ;
- liens Markdown locaux cassés dans le portail documentaire ;
- retour de textes de maintenance spécifiques à un outil externe dans la documentation publique.

## Limite d'automatisation

Les réglages GitHub de protection/merge ne sont jamais modifiés par `install.sh --apply`. Ils appartiennent à l'administration du dépôt, séparée de la convergence Fedora.

La configuration attendue est vérifiée après modification via l'API publique du dépôt. Si l'identité d'administration utilisée ne possède pas l'écriture `administration`, la modification doit être faite par un mécanisme GitHub explicitement autorisé ; la documentation seule ne constitue jamais une preuve que le réglage live est actif.
