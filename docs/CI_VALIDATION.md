# CI et validation bout-en-bout

La CI combine contrats statiques, intégration Fedora 44 et vraie VM Ubuntu 26.04. Elle complète les certifications sur la machine physique ; elle ne les remplace pas.

## Tests de contrats

`.github/workflows/tests.yml` valide structure, politiques hardware/GNOME, applications, multimédia, KVM, bootstrap Ubuntu, accès VM, backup/recovery, gouvernance CI, Bash UX, dock et durcissement pré-1.0.

## Shell quality

Tous les scripts suivis sont vérifiés par `bash -n` et ShellCheck. Les exemptions globales ont été réduites : les variables locales inutilisées et les fautes de noms ne sont plus masquées globalement.

## Fedora 44 package preflight

Résolution des manifests, RPM Fusion, dépôts VS Code/Brave, Flathub, swaps multimédia et extensions GNOME 50. Ce workflow tourne sur push/PR et **chaque dimanche** pour détecter une rupture externe sans commit.

## Fedora 44 host integration pretest

Dans un conteneur Fedora 44, installe réellement le contrat HOST/GNOME/KVM/backup, teste Bash UX et le dock via un utilisateur normal, valide RPM Fusion, vendor RPM, Flathub et extensions. Il tourne aussi chaque semaine.

## Architecture non-regression

Bloque notamment : ouverture du gate machine réelle, confusion VM/conteneur avec bare-metal, X11 comme contrat, `force_probe`, GPU passthrough, VirtioFS host-share, affaiblissement KVM, flush firewall, formatage dans les modules, SSH guest par mot de passe, installateur AWS non signé, Kickstart non piné et affaiblissement du backup fail-closed.

## Ubuntu 26.04 real VM pretest

Télécharge l'image Canonical authentifiée, démarre une vraie VM QEMU (KVM si disponible, TCG sinon), exécute le bootstrap exact, vérifie Docker/Node/Java/Kubernetes/cloud/IaC puis redémarre pour tester la persistance. Il tourne aussi chaque semaine afin de surveiller les dépôts externes et signatures.

## Ce qui reste bare-metal

Arc B580/`xe`, Level Zero/OpenCL réel, GNOME/Wayland/display 240 Hz, suspend/resume, les deux T705, le firmware/BIOS, Secure Boot et l'isolation LAN KVM nécessitent le matériel final.

Voir aussi `docs/GITHUB_GOVERNANCE.md` et `docs/SUPPLY_CHAIN.md`.
