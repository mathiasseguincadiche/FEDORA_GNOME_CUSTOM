# GitHub governance — pré-1.0

`main` est une branche de production : aucun changement ne doit contourner la validation automatisée.

## Ruleset attendu sur `main`

Configurer dans GitHub un ruleset ciblant `refs/heads/main` avec :

- pull request obligatoire avant fusion ;
- interdiction des force-push ;
- interdiction de supprimer `main` ;
- branche à jour avant fusion ;
- checks obligatoires : **Tests**, **Shell quality**, **Architecture non-regression**, **Fedora 44 package preflight**, **Fedora 44 host integration pretest** ;
- le workflow Ubuntu 26.04 doit être vert lorsqu'il est déclenché par une modification de la VM, de son bootstrap ou de sa supply-chain.

Le dépôt contient :

```bash
scripts/development/check-main-protection.sh
```

pour vérifier l'état public attendu de la protection. Ce script ne modifie aucun réglage GitHub.

## Discipline de branche

Les changements fonctionnels ou structurants sont préparés sur une branche dédiée puis proposés par pull request.

Le but n'est pas de multiplier les branches longues : `main` doit rester la représentation intégrable de la Golden Workstation, avec historique de revue et checks visibles.

## Discipline de release

Toute modification fonctionnelle fusionnée dans `main` doit être reflétée dans :

```text
VERSION
CHANGELOG.md
README.md lorsque le contrat utilisateur change
```

Les documents normatifs ne recopient pas inutilement le numéro de release dans leur titre ; ils suivent la version indiquée par `VERSION`. Les anciens numéros restent acceptables dans les release notes et le changelog lorsqu'ils décrivent explicitement l'historique.

## Contrat documentaire

La documentation est traitée comme une partie du produit. La CI doit notamment empêcher :

- commandes documentées qui n'existent plus ;
- contradiction entre profil GNOME et extensions réellement gérées ;
- valeurs KVM documentées différentes de `virtualization.conf`/XML ;
- oubli d'une application professionnelle déjà présente dans les manifests ;
- liens Markdown locaux cassés dans le portail documentaire ;
- retour de textes de maintenance spécifiques à un outil externe dans la documentation publique.

## Limite d'automatisation

Les réglages de protection GitHub ne sont jamais modifiés par `install.sh --apply`. Ils appartiennent à l'administration du dépôt, séparée de la convergence Fedora.

Si l'outil utilisé pour administrer GitHub ne possède pas les droits d'écriture nécessaires, le ruleset doit être configuré depuis un compte ou mécanisme disposant explicitement de ces droits. Cette contrainte d'administration n'appartient pas à l'architecture runtime de la workstation.
