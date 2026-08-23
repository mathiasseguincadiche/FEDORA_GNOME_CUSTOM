# Troubleshooting

## Affichage/polices dégradés

Ne changez pas Fontconfig en premier. Exécuter :

```bash
./diagnostics/graphics-doctor
./diagnostics/gnome-doctor
journalctl -k -b | grep -Ei 'xe|drm'
```

Comparer avec la dernière capture suspend/resume si le défaut apparaît après veille.

## Réveil de veille incorrect

```bash
./diagnostics/suspend-doctor
cat /sys/power/mem_sleep
```

Ne forcez `deep` ou `s2idle` qu'après reproduction et analyse.

## Redémarrage inexpliqué

```bash
./scripts/collect-boot-failure.sh
journalctl -b -1 -p warning..alert
coredumpctl list
```

## GPU

Le fonctionnement attendu est Arc B580 `8086:e20b` + pilote `xe`. Aucun `force_probe` n'est prévu.
