# Desktop & Lifecycle — politique 0.10.0

## Capacités quotidiennes

La workstation certifie GNOME Keyring/Secret Service, portals Wayland, impression/scan driverless, VPN NetworkManager, TuneD PPD, français/polices, Remmina, support mobile et Intel Arc compute.

## RPM Fedora

`/etc/dnf/automatic.conf` est convergé avec :

- téléchargement automatique : **oui** ;
- installation automatique : **non** ;
- reboot automatique : **jamais**.

`dnf5-automatic.timer`, `fstrim.timer` et, lorsqu'il existe, `fwupd-refresh.timer` sont activés. Le timer fwupd rafraîchit les métadonnées, il ne flashe aucun firmware de façon autonome.

## Flatpak

Politique explicite : `LIFECYCLE_FLATPAK_UPDATE_POLICY="manual"`.

Les applications Flatpak sont mises à jour volontairement via GNOME Software ou :

```bash
flatpak update
```

Le projet ne crée aucun timer/service d'installation Flatpak silencieuse. `lifecycle-doctor` refuse un updater Flatpak portant le namespace du projet s'il apparaît.

## Sauvegarde quotidienne

Le timer Restic sauvegarde les données utilisateur uniquement lorsque le repository et la passphrase sécurisée sont accessibles. Chiffrement obligatoire, passphrase exclue, pas de prune automatique ; absence du disque externe = skip propre. Le backup pré-APPLY reste indépendant et fail-closed.

## Veille / affichage

Chaque preuve suspend possède un `cycle_id` unique et un fingerprint runtime incluant la stack graphique critique. Un changement de kernel/firmware GPU/Mesa/Mutter/GNOME Shell impose de nouvelles preuves.

## KVM

Le host KVM fait désormais partie de `final-certification` lorsque `ENABLE_KVM=true`. La certification des invités reste une étape runtime distincte via `scripts/kvm/runtime_certification.sh`.

## Limite physique

La CI ne simule pas Arc B580/Wayland/240 Hz/suspend, les deux NVMe ni le LAN physique. La certification finale reste bare-metal.
