# ADR 0003 — Kernel Vanilla candidate/certified

**Statut : accepté**

## Décision

Le channel Kernel Vanilla stable peut fournir un candidat plus récent que Fedora, mais aucune version n'est automatiquement Golden.

```text
resolve exact repo/NEVRA → candidate → one-shot boot → qualification → certify
```

Un kernel Fedora 44 officiel reste obligatoirement installé comme fallback.
