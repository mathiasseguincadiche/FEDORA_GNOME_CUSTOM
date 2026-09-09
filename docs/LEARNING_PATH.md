# Parcours d'apprentissage — Fedora 44 Golden Workstation

Ce document est le **guide de lecture** du dépôt. Il ne remplace pas les procédures : il explique **dans quel ordre les lire**, ce qu'il faut comprendre à chaque étape et quand passer au niveau suivant.

Si vous découvrez le projet, commencez ici avant de parcourir les références techniques au hasard.

---

## 1. Choisir son parcours

| Besoin | Parcours recommandé | Résultat attendu |
|---|---|---|
| **Comprendre le projet rapidement** | Niveau 1 — Découvrir | Comprendre ce qu'est la Golden, ses composants et ses limites |
| **Exploiter la workstation** | Niveau 2 — Opérer | Savoir utiliser `./control.sh`, diagnostiquer et agir sans contourner les garde-fous |
| **Installer et certifier** | Niveau 3 — Construire | Savoir préparer le bare-metal, exécuter APPLY et produire Gate 3 |
| **Maintenir ou contribuer** | Niveau 4 — Maintenir | Comprendre les contrats, la CI, les ADR et l'ordre d'autorité |

---

# Niveau 1 — Découvrir

**Objectif :** comprendre le système avant d'exécuter des commandes de mutation.

Temps de lecture indicatif : 15 à 25 minutes.

Lire dans cet ordre :

1. [`../README.md`](../README.md) — vue produit, statut et architecture ;
2. [`README.md`](README.md) — carte de toute la documentation ;
3. [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture et invariants ;
4. [`GLOSSARY.md`](GLOSSARY.md) — vocabulaire lorsqu'un terme n'est pas clair.

### À la fin de ce niveau, vous devez pouvoir expliquer

- pourquoi la workstation est traitée comme une infrastructure versionnée ;
- la différence entre le T705 système et le T705 `/data` ;
- le rôle du Kernel Vanilla N / N-1 ;
- pourquoi Gaming et KVM sont des workloads contrôlés ;
- la différence entre `CODE-READY` et `Golden runtime-certified` ;
- pourquoi Gate 1 et Gate 2 ne constituent jamais une certification physique.

Si un de ces points reste flou, ne passez pas encore à l'installation bare-metal.

---

# Niveau 2 — Opérer

**Objectif :** utiliser la machine et ses outils de façon sûre.

Lire :

1. [`CONTROL_CENTER.md`](CONTROL_CENTER.md) ;
2. [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) ;
3. [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) ;
4. puis le guide spécialisé correspondant au besoin : [`GAMING.md`](GAMING.md), [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) ou [`DESKTOP_LIFECYCLE.md`](DESKTOP_LIFECYCLE.md).

## Réflexe opérateur

Toujours partir de l'état observé :

```text
status
  ↓
doctor / diagnostic
  ↓
comprendre le symptôme
  ↓
choisir la procédure documentée
  ↓
mutation protégée si nécessaire
  ↓
revalidation
```

Commandes de départ :

```bash
./control.sh status
./control.sh doctor all
```

### Vocabulaire de sécurité

| Classe | Signification | Exemple |
|---|---|---|
| **Observation** | Lecture seule | `./control.sh status` |
| **Plan / dry-run** | Prépare ou vérifie sans appliquer la convergence réelle | `./control.sh install dry-run` |
| **Mutation protégée** | Modifie l'état avec préconditions et garde-fous | `./control.sh update all` |
| **Opération destructive ou firmware** | Demande une action humaine explicite hors automatisation aveugle | préparation disque, flash firmware |

Une commande de diagnostic qui échoue est une information à comprendre, pas une invitation à désactiver SELinux, firewalld ou un guard fail-closed.

---

# Niveau 3 — Construire et certifier

**Objectif :** produire la vraie workstation Golden sur le matériel cible.

Lire **avant toute mutation bare-metal** :

1. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) ;
2. [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) ;
3. [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md) ;
4. [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) ;
5. [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md).

Le chemin mental est :

```text
média vérifié
    ↓
stockage préparé
    ↓
baseline hardware
    ↓
dry-run lié au commit + config + hardware
    ↓
backup pré-APPLY vérifié
    ↓
APPLY bare-metal
    ↓
reboot + diagnostics
    ↓
Gate 3 physique
    ↓
Golden runtime-certified
```

### Ne pas continuer si

- le média Fedora n'est pas authentifié ;
- le second T705 n'est pas identifié sans ambiguïté ;
- `/data` n'est pas monté sur le bon disque ;
- la baseline n'est pas certifiée ;
- le dry-run est obsolète ;
- le backup pré-APPLY n'est pas vérifiable ;
- Secure Boot est actif ou son état est indéterminé ;
- le dépôt Git n'est pas propre.

Le projet est volontairement fail-closed : **un blocage est une protection du contrat**, pas un obstacle à contourner.

---

# Niveau 4 — Maintenir et contribuer

**Objectif :** modifier le projet sans introduire de divergence entre comportement, documentation et preuves.

Lire :

1. [`DOCUMENTATION_MODEL.md`](DOCUMENTATION_MODEL.md) ;
2. [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md) ;
3. [`CI_VALIDATION.md`](CI_VALIDATION.md) ;
4. [`GITHUB_GOVERNANCE.md`](GITHUB_GOVERNANCE.md) ;
5. [`adr/README.md`](adr/README.md) ;
6. [`../CONTRIBUTING.md`](../CONTRIBUTING.md).

Ordre d'autorité :

```text
code + config + tests
        ↓
documents normatifs
        ↓
guides / références / runbooks
        ↓
historique
```

Un changement est incomplet s'il modifie un contrat utilisateur sans mettre à jour la documentation et les tests correspondants.

---

## 5. Où aller selon le symptôme

| Situation | Première lecture |
|---|---|
| APPLY refusé | [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md), puis [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) |
| Problème GPU / affichage / kernel | [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md) |
| Problème `/data`, XDG ou Steam | [`RUNBOOK_PERSISTENT_DATA_GAMING.md`](RUNBOOK_PERSISTENT_DATA_GAMING.md) |
| Problème KVM / réseau VM | [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md) |
| Backup ou restauration | [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) |
| GNOME / desktop | [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md), puis [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) |
| Doute sur un terme | [`GLOSSARY.md`](GLOSSARY.md) |
| Doute sur la source de vérité | [`DOCUMENTATION_MODEL.md`](DOCUMENTATION_MODEL.md) |

---

## 6. Deux statuts à ne jamais confondre

### CODE-READY

Le code, les configurations, la documentation et les contrôles CI couverts sont cohérents et prêts pour le parcours d'installation.

### Golden runtime-certified

La vraie machine cible a terminé Gate 3 et la certification finale sur le runtime physique courant.

```text
CODE-READY
    ≠
certification physique

CODE-READY + installation + Gate 3 PASS
    =
Golden runtime-certified
```

---

## 7. Règle de lecture

Une documentation excellente ne demande pas au lecteur de deviner l'étape suivante.

Pour chaque opération importante, cherchez toujours quatre réponses :

1. **Pourquoi** cette étape existe ?
2. **Quelles préconditions** doivent être vraies ?
3. **Quel résultat** prouve qu'elle est réussie ?
4. **Que faire ensuite** — ou quand faut-il s'arrêter ?

Si une procédure du dépôt ne permet plus de répondre clairement à ces quatre questions, elle doit être améliorée comme n'importe quel autre contrat du projet.
