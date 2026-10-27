# Fedora 44 / GNOME 50 : historique facultatif

La référence d’installation neuve est [Fedora 45 / GNOME 51](FEDORA45_PRIMARY.md). Fedora 44 est conservé pour relire les décisions antérieures, comparer un comportement ou préparer la migration d’un poste déjà installé.

- `.github/workflows/fedora44-legacy-lab.yml` se lance uniquement par `workflow_dispatch`. Il n’est pas une dépendance de `Tests / contracts`.
- Les verrous d’extensions et de Nautilus propres à 44 sont dans `profiles/fedora44/` ; les médias historiques restent explicitement nommés `fedora44`.
- `installer/generate-fedora44-kickstart.sh` et `installer/verify-fedora44-media.sh` sont des adaptateurs historiques explicites. Les entrées génériques et `generate-fedora45-kickstart.sh` sélectionnent uniquement 45 et refusent `--release 44`.
- `HOST_RELEASE="44"` doit être une sélection locale explicite pour inspecter un ancien poste. L’APPLY de production exige Fedora 45 promu. Le parcours courant est Live USB puis qualification du système installé.
- [UPGRADE_FEDORA_45.md](UPGRADE_FEDORA_45.md) est réservé à un système déjà sous 44 ; il ne fait pas partie de l’installation neuve.

Les documents dans `history/` et les ADR antérieurs gardent leurs versions d’origine. La décision active est [ADR 0018](adr/0018-fedora45-primary.md). Une ancienne preuve GNOME 50 ne certifie pas GNOME 51.
