# ADR 0001 — Fedora 44 + GNOME 50

> Choix de version remplacé par [ADR 0018](0018-fedora45-primary.md). Conservé pour l’historique.

**Statut : remplacé par ADR 0018**

## Contexte

La workstation est un OS principal DevOps, graphique et KVM, avec besoin d'une pile récente pour Arc B580 tout en conservant une distribution intégrée.

## Décision

Fedora Linux 44 Workstation et GNOME 50/Wayland sont la référence unique du HOST.

## Conséquences

Les modules refusent une autre release Fedora pour la certification. Les upgrades de distribution sont des migrations de plateforme, pas des mises à jour ordinaires.
