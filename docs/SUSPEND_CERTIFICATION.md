# Suspend / Resume certification

Le hook `/usr/lib/systemd/system-sleep/fedora-gnome-custom` est volontairement minimal. Il écrit uniquement phase/action/horodatage et demande de façon non bloquante un service post-resume. Les lectures PCIe, GPU, NVMe, audio, réseau et journald sont réalisées ensuite par `fedora-gnome-custom-resume-health.service`.

La certification réelle s'exécute explicitement :

```bash
scripts/hardware/suspend-certify.sh --execute --cycles 10
```

Un PASS exige l'absence de GPU HANG/wedged, erreur matérielle, AER fatal et lockup watchdog dans les preuves collectées. Le projet n'impose pas `s2idle` ou `deep` automatiquement ; un changement de `mem_sleep` doit être motivé par des mesures comparatives sur la machine réelle.
