# ADR 0004 — Btrfs root + EXT4 KVM

**Statut : accepté**

Fedora utilise Btrfs non chiffré sur le T705 système. Les images KVM utilisent un second T705 préparé manuellement en EXT4 sur `/data`.

Le dépôt ne partitionne ni ne formate automatiquement le second SSD. Cette séparation réduit le couplage entre lifecycle HOST et I/O des VM.
