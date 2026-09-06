# ADR 0008 — Aucun flash firmware automatique

**Statut : accepté**

`fwupd` sert à l'inventaire et à la détection de mises à jour. Aucun timer ni chemin de maintenance du projet ne flashe automatiquement BIOS, périphériques ou firmware.

Un changement firmware est une opération opérateur explicite suivie d'une nouvelle qualification si la pile certifiée est affectée.
