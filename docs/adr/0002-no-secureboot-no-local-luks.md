# ADR 0002 — Secure Boot OFF et aucun chiffrement local du HOST

**Statut : accepté**

## Décision

Secure Boot doit être désactivé et les block devices locaux du HOST ne doivent utiliser ni LUKS ni dm-crypt.

## Conséquences

La workstation ne protège pas les SSD contre un accès physique offline. SELinux, firewalld, contrôles de provenance et sauvegardes restent actifs. Les repositories Restic externes restent chiffrés : cette protection n'est pas du chiffrement du stockage local du HOST.
