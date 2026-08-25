# Kernel policy

Fedora 44 reste la source du kernel, des modules, du microcode et de `linux-firmware`. Le projet refuse les kernels custom automatiques et les arguments globaux de contournement connus pour masquer les causes réelles de panne.

`kernel-doctor` vérifie le build Fedora 44, le taint, la cmdline, AMD P-State, le microcode, pstore et l'état de kdump. Les générations Fedora précédentes servent de rollback opérateur ; aucune suppression agressive des kernels de secours n'est automatisée.

Les paramètres expérimentaux ne peuvent être introduits qu'après reproduction d'un défaut, preuve avant/après et procédure de retour arrière.
