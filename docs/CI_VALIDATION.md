# CI et validation bout-en-bout

La CI combine contrats statiques, intégration Fedora 44 et vraie VM Ubuntu 26.04. Elle complète les certifications sur la machine physique ; elle ne les remplace pas.

## Tests de contrats

`.github/workflows/tests.yml` valide notamment :

- structure et politiques hardware/GNOME ;
- applications et multimédia ;
- KVM/libvirt ;
- bootstrap Ubuntu ;
- accès VM ;
- backup/recovery ;
- gouvernance CI ;
- Bash UX et dock ;
- durcissement pré-1.0 ;
- **fail-closed du guard KVM** ;
- **authentification de l'image Ubuntu** ;
- **cohérence documentation ↔ code/config**.

## Contrat documentaire

La documentation est testée comme une partie du produit.

La CI bloque notamment :

- retour d'anciennes commandes `baseline-doctor record-*` ;
- profil GNOME qui oublierait AppIndicator ;
- disparition de draw.io du catalogue documentaire alors qu'il reste géré ;
- valeurs `devops-nat`/`virbr50`/CIDR incohérentes avec la configuration ;
- suppression du portail débutant/glossaire/runbook ;
- liens Markdown locaux cassés dans les documents inspectés ;
- réintroduction de notes publiques spécifiques à un connector/outillage de maintenance.

Ce test ne remplace pas la relecture éditoriale humaine, mais empêche les divergences factuelles déjà identifiées de revenir silencieusement.

## Shell quality

Tous les scripts suivis sont vérifiés par `bash -n` et ShellCheck.

Les exemptions globales sont limitées afin que les variables inutilisées et fautes de noms ne soient pas masquées à l'échelle du dépôt.

## Fedora 44 package preflight

Résolution des manifests, RPM Fusion, dépôts VS Code/Brave, Flathub, swaps multimédia, extensions GNOME 50 et packages KVM, y compris GnuPG nécessaire à l'authentification d'image Ubuntu.

Ce workflow tourne sur push/PR et périodiquement afin de détecter une rupture externe sans commit.

## Fedora 44 host integration pretest

Dans un conteneur Fedora 44, installe réellement le contrat HOST/GNOME/KVM/backup, teste Bash UX et dock via un utilisateur normal, valide RPM Fusion, vendor RPM, Flathub et extensions.

Il tourne aussi périodiquement.

## Architecture non-regression

Bloque notamment :

- ouverture du gate machine réelle ;
- confusion VM/conteneur avec bare-metal ;
- X11 comme contrat ;
- `force_probe` ;
- GPU passthrough ;
- VirtioFS HOST-share ;
- affaiblissement KVM ;
- flush firewall ;
- formatage dans les modules ;
- SSH guest par mot de passe ;
- installateur AWS non signé ;
- Kickstart non piné ;
- affaiblissement du backup fail-closed.

## KVM network fail-closed

Le contrat statique exige :

```text
mode emergency
        ↓
reconcile
        ↓
mode normal seulement après validation
```

Le dispatcher NetworkManager ne doit plus masquer un échec de reload avec `|| true` et ne doit pas lancer un reload asynchrone laissant une fenêtre où l'ancien LAN serait considéré encore valide.

La preuve runtime finale reste bare-metal.

## Authentification image Ubuntu

Le contrat exige :

- empreinte Canonical épinglée ;
- signature GPG de `SHA256SUMS` ;
- SHA-256 de l'image ;
- appel du verifier par le script de création ;
- politique activée dans `vm-profiles.conf`.

## Ubuntu 26.04 real VM pretest

Le workflow :

1. télécharge l'image Canonical ;
2. télécharge `SHA256SUMS` et sa signature ;
3. authentifie la liste ;
4. vérifie l'image ;
5. démarre une vraie VM QEMU (KVM si disponible, TCG sinon) ;
6. exécute le bootstrap exact ;
7. vérifie Docker/Node/Java/Kubernetes/cloud/IaC ;
8. redémarre pour tester la persistance.

Il tourne périodiquement afin de surveiller les dépôts externes et signatures.

## Ce qui reste bare-metal

- Arc B580/`xe` ;
- Level Zero/OpenCL réel ;
- GNOME/Wayland/display 240 Hz ;
- suspend/resume ;
- les deux T705 ;
- firmware/BIOS ;
- Secure Boot ;
- isolation LAN KVM réelle ;
- changement Ethernet/Wi-Fi réel ;
- second-host LAN → VM.

Voir aussi [`GITHUB_GOVERNANCE.md`](GITHUB_GOVERNANCE.md) et [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md).
