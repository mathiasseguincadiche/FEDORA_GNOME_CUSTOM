# ADR 0019 — Validation native Live USB puis système installé

## Statut

Accepté. Remplace ADR 0009 pour le parcours opérateur.

## Contexte

L’installation prévue est neuve, directement en Fedora 45 / GNOME 51. Le propriétaire teste le PC depuis une clé Live avant installation et retire entièrement le profil VM Windows 11. Un parcours WSL2 ou VirtualBox n’apporte pas de preuve sur le matériel cible et ne fait plus partie des étapes demandées.

## Décision

- Conserver les tests automatisés Linux et les laboratoires QEMU comme preuves logicielles liées au commit exact.
- Exécuter les observations avant installation depuis Fedora Live, sur le PC réel, sans converger sa session temporaire.
- Exporter le compte rendu natif au schéma 2 hors du Live, puis l’importer sur Fedora installé au même commit et au même plan de modules. L’identité du PC est stable malgré le changement de racine et de noyau.
- Limiter cette preuve à `PREINSTALL_ONLY` : les extensions personnalisées, services, sauvegardes et KVM se qualifient après installation et APPLY.
- Retirer le profil Windows 11, ses commandes et ses contrôles de certification. Rocky reste l’unique invité géré ; sa création intervient après les premiers diagnostics de l’hôte installé.
- Conserver la Gate 3 comme qualification complète du système final et de ses usages réels.

## Conséquences

Une seule preuve native remplace les deux anciennes prévalidations virtuelles. Les anciens JSON sont refusés. Les changements de commit ou de plan exigent un nouveau relevé Live ; les changements de configuration ou de runtime installés exigent la requalification des preuves concernées. Aucun résultat CI ou Live ne devient automatiquement une certification Golden.

Les politiques du projet concernant `/data`, Secure Boot OFF, l’absence de LUKS local, Borg non chiffré et les exports manuels de VM restent inchangées. Les procédures courantes sont [le Live USB](../FEDORA45_LIVE_PREFLIGHT.md), [l’installation](../INSTALLATION_GUIDE.md) et [la validation](../QUALIFICATION.md).
