# ADR 0006 — Pile GPU Fedora native

**Statut : accepté**

La pile graphique utilise le kernel, `linux-firmware`, `intel-gpu-firmware` et Mesa fournis par Fedora. `force_probe`, Mesa Git/COPR et dépôts de pilotes GPU tiers sont exclus.

RPM Fusion est autorisé uniquement pour les composants multimédia/gaming explicitement gérés.
