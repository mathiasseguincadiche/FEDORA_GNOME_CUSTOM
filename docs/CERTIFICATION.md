# Prouver que la machine est prête — guide d'entrée

Ce guide est la **porte d'entrée** du pilier « fiabilité » côté preuves : comment le projet passe de « le code est correct » à « cette machine précise est certifiée ». Il ne répète pas le détail : il donne l'ordre des étapes et le document de chacune.

## Le principe

Un réglage n'est pas considéré comme bon parce qu'il est écrit, ni parce qu'un paquet est installé : il faut une **preuve** qui correspond au commit, à la configuration et au matériel exacts. Une preuve qui ne correspond plus (nouveau commit, nouveau noyau, autre machine) devient `STALE` et doit être refaite.

Le projet distingue donc deux états :

- **code prêt** : la CI est verte ; aucune machine n'est certifiée par la CI ;
- **machine certifiée** : `./diagnostics/final-certification certify` a produit un PASS sur le vrai PC.

## Le parcours, dans l'ordre

| Étape | Où | Ce qu'elle prouve | Document |
| --- | --- | --- | --- |
| 0. CI | GitHub, automatiquement | Contrats, tests, vraie VM Fedora GNOME, vraie VM Rocky | [`CI_VALIDATION.md`](CI_VALIDATION.md), [`FEDORA_GNOME_CI_LAB.md`](FEDORA_GNOME_CI_LAB.md) |
| 1. Gate 1 | Fedora 44 dans WSL2 | Logique du projet, garde-fous | [`WSL2_VALIDATION.md`](WSL2_VALIDATION.md) |
| 2. Gate 2 | Fedora 44 GNOME dans VirtualBox | Bureau réel et validation visuelle humaine | [`GATE2_GUIDE_PAS_A_PAS.md`](GATE2_GUIDE_PAS_A_PAS.md), [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) |
| 3. Baseline | Vrai PC, avant toute modification | Matériel assez sain pour autoriser l'installation | [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) |
| 4. Installation | Vrai PC | Dry-run, sauvegarde, APPLY protégé | [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md), [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md) |
| 5. Gate 3 | Vrai PC, après installation | Matériel, logiciels, bureau, stabilité | [`PHYSICAL_QUALIFICATION_CHECKLIST.md`](PHYSICAL_QUALIFICATION_CHECKLIST.md), [`STACK_CERTIFICATION.md`](STACK_CERTIFICATION.md), [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md) |
| 6. Version figée | Vrai PC certifié | État exact relié à toute sa chaîne de preuves | [`GOLDEN_RELEASE.md`](GOLDEN_RELEASE.md) |

L'ordre officiel complet, avec toutes les commandes, est dans [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md). Règle d'or : **les trois gates utilisent le même commit**.

## Documents de référence

| Sujet | Document |
| --- | --- |
| Ce que « Golden » veut dire, runtime certifié ou non | [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) |
| Stabilité matérielle : mesurer avant de corriger | [`HARDWARE_STABILITY.md`](HARDWARE_STABILITY.md) |
| Ordre de qualification après correction des faux PASS | [`RELIABILITY_QUALIFICATION.md`](RELIABILITY_QUALIFICATION.md) |
| Fiche à remplir pendant un essai physique | [`QUALIFICATION_EVIDENCE_TEMPLATE.md`](QUALIFICATION_EVIDENCE_TEMPLATE.md) |
| Dépannage matériel pendant la Gate 3 | [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md) |

## Où en est le projet

Code prêt, machine non certifiée : la prochaine étape est la Gate 1 puis la Gate 2, avec [`GATE2_GUIDE_PAS_A_PAS.md`](GATE2_GUIDE_PAS_A_PAS.md).
