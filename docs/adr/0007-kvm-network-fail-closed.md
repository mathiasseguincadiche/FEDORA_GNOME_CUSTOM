# ADR 0007 — Réseau KVM fail-closed

**Statut : accepté**

`devops-nat` reste IPv4 et utilise un guard nftables qui protège les réseaux HOST explicitement routés. Lors d'une transition réseau, le mode emergency est installé avant la reconstruction du mode normal.

Si la topologie ne peut pas être prouvée, le forwarding VM est bloqué plutôt que conservé sur une hypothèse périmée.
