# ADR 0009 — Validation en trois gates

## Statut

Accepté.

## Contexte

La Golden Workstation doit être validée progressivement sans transformer une preuve issue d'un environnement virtualisé en preuve matérielle. WSL2 est utile pour exécuter la logique système et les contrats, VirtualBox pour observer le desktop GNOME, mais ni l'un ni l'autre ne peut certifier le PCIe, ReBAR, SMART, EDID, firmware ou suspend/resume de la machine physique.

## Décision

Le projet adopte trois gates ordonnées :

1. **Gate 1 — Fedora 44 sous WSL2** : prévalidation système, contrats, dry-run et logique fail-closed. Toute preuve matérielle reste `DEFERRED`.
2. **Gate 2 — Fedora 44 GNOME sous Oracle VirtualBox** : convergence et validation du desktop GNOME/Nautilus/Ptyxis/extensions, complétée par un contrôle visuel humain explicite. Toute preuve matérielle reste `DEFERRED`.
3. **Gate 3 — Fedora 44 bare-metal** : seule autorité capable de produire `final-certification PASS` et `golden-release.json`.

Les preuves Gate 1 et Gate 2 sont des JSON portables liés au commit Git et au `module-plan`. Gate 2 contient le SHA-256 de Gate 1. Gate 3 exige les deux preuves importées et leur chaîne intacte.

## Conséquences

- une modification du commit ou du module plan invalide les preuves antérieures ;
- Gate 1 et Gate 2 ne peuvent pas être utilisées comme raccourci de certification hardware ;
- la validation desktop reste possible avant installation bare-metal ;
- la certification finale devient traçable jusqu'aux deux prévalidations ;
- le bundle Golden embarque les deux preuves et leurs SHA-256.

## Invariants actuels

- Fedora 44 / GNOME 50 / Wayland ;
- Secure Boot OFF ;
- aucun LUKS local ;
- Restic externe chiffré ;
- Arc B580 host-only ;
- Kernel Vanilla rolling N / N-1, maximum deux versions ;
- récupération Fedora explicite, sans fallback Fedora permanent ;
- KVM réseau fail-closed ;
- aucun flash firmware automatique.

La politique kernel détaillée est portée par ADR 0010 ; elle remplace l'ancien invariant de fallback Fedora permanent sans modifier la séparation des trois gates.
