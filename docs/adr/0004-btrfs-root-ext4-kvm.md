# ADR 0004 — Btrfs root + EXT4 KVM

**Statut : remplacé par ADR 0011**

Cette décision a établi la séparation physique entre le T705 système Btrfs et un second T705 EXT4 monté sur `/data`, ainsi que l'interdiction pour le dépôt de partitionner ou formater automatiquement ce second SSD.

ADR 0011 conserve ces invariants mais élargit le rôle de `/data` : le second T705 devient le stockage persistant de la workstation, avec des répertoires utilisateur dédiés et un sous-arbre `/data/libvirt` réservé à KVM.
