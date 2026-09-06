# ADR 0005 — Intel Arc B580 réservée au HOST

**Statut : accepté**

L'Arc B580 `8086:e20b` reste attachée au HOST via `xe`. Le Golden n'active aucun GPU passthrough.

La B580 porte le desktop Wayland, l'accélération média et le compute ; la certification exige ReBAR, PCIe x8, VA-API et OpenCL fonctionnels.
