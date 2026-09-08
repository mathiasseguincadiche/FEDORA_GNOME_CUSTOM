# ADR 0003 — Kernel Vanilla candidate/certified

**Statut : remplacé par ADR 0010**

## Décision historique

Le channel Kernel Vanilla stable pouvait fournir un candidat plus récent que Fedora, mais aucune version n'était automatiquement Golden.

```text
resolve exact repo/NEVRA → candidate → one-shot boot → qualification → certify
```

Un kernel Fedora 44 officiel restait obligatoirement installé comme fallback.

## Remplacement

Cette politique a été remplacée par [ADR 0010 — Kernel Vanilla rolling N / N-1](0010-kernel-rolling-n-nminus1.md).

La décision actuelle installe directement le dernier stable, conserve uniquement N et N-1 et utilise la certification Golden comme preuve post-update plutôt que comme gate de promotion préalable au boot.
