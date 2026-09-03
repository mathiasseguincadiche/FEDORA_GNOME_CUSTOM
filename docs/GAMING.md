# Gaming profile — Fedora 44 / GNOME 50 / Intel Arc B580

## Scope

The Gaming profile is an optional Golden workstation capability. It adds the Linux gaming runtime without changing the DevOps/KVM isolation boundary, without replacing Fedora's kernel/Mesa stack, and without applying global performance tweaks.

The profile is disabled by default. Enable it persistently for this workstation by setting the validated local override:

```bash
GAMING_ENABLE="true"
```

in `config/local.conf`, or enable it for one explicit APPLY run with:

```bash
GAMING_ENABLE=true ./install.sh
```

The canonical project default remains `GAMING_ENABLE="false"` in `config/gaming.conf`, so a workstation that does not request gaming remains unchanged.

## Golden stack

### Steam

Steam is installed as the native RPM from RPM Fusion's dedicated `rpmfusion-nonfree-steam` repository. The repository is enabled only for the Steam installation transaction; the project does not add a third-party GPU repository.

### Proton policy

Compatibility order:

1. Valve Proton managed by Steam;
2. Proton Experimental when a title needs a newer Valve compatibility layer;
3. Proton-GE only as an explicit per-title exception.

The Golden profile never downloads Proton-GE automatically, never makes it the global compatibility tool, and does not install system Wine merely because Steam is enabled.

### Vulkan and 32-bit compatibility

Steam/Proton require both native x86_64 and i686 userspace graphics libraries. The profile therefore converges:

- `mesa-vulkan-drivers.x86_64` and `.i686`;
- `mesa-dri-drivers.x86_64` and `.i686`;
- `vulkan-loader.x86_64` and `.i686`;
- `vulkan-tools` for diagnostics.

The GPU driver remains Fedora's kernel `xe` driver with Fedora Mesa/ANV. No `mesa-git`, COPR Mesa build, Intel GPU repository, `force_probe`, or custom gaming kernel belongs to the Golden contract.

### Gaming helpers

- GameMode — temporary per-game performance policy;
- MangoHud — FPS/frametime/GPU/CPU telemetry;
- GOverlay — graphical configuration for gaming overlays;
- Gamescope — optional per-title micro-compositor;
- `steam-devices` — udev permissions for supported controllers and Steam-related devices.

None of these tools is injected globally into every game.

## Launch policy

Default launch option: none. Start with the game's normal Steam launch path and add helpers only when useful.

Examples:

```text
# GameMode only
gamemoderun %command%

# MangoHud only
mangohud %command%

# MangoHud + GameMode
mangohud gamemoderun %command%
```

Gamescope options are title/display specific and must not become a universal launch string.

## CI versus bare-metal evidence

The Fedora 44 gaming pretest validates in a headless Fedora container:

- Fedora/RPM Fusion package availability;
- Steam RPM installation and binary ownership without launching the Steam GUI;
- Vulkan x86_64/i686 userspace payload;
- GameMode, MangoHud, GOverlay, Gamescope and Steam Input packages/commands;
- repository policy;
- static project contracts.

CI does **not** claim GPU rendering, VRR, 240 Hz, or successful game launch.

On the physical workstation, `diagnostics/gaming-doctor` additionally checks the existing Arc/display contracts:

- Intel Arc B580 bound to `xe`;
- Intel Arc Vulkan renderer visible through `vulkaninfo`;
- GNOME/Wayland;
- 2560×1440 at the configured 240 Hz target;
- VRR/adaptive-sync visibility when exposed by GNOME tooling;
- Steam-managed Proton presence after Steam has initialized compatibility tools.

A missing Proton payload on a fresh Steam installation is a warning, not a failure: Steam downloads compatibility tools on demand.

## Certification workflow

After the Gaming profile has been applied and the workstation rebooted, validate the dedicated stack on the physical machine:

```bash
GAMING_ENABLE=true ./diagnostics/gaming-doctor
```

Then run the normal Golden certification path. When `GAMING_ENABLE=true`, `diagnostics/final-certification certify` invokes `gaming-doctor --quiet`; when the profile is disabled, Gaming is intentionally excluded from the mandatory bare-metal certificate.

The final Gaming proof therefore has two levels:

1. GitHub Actions proves package resolution, native RPM ownership, multilib Vulkan payload and project contracts on Fedora 44;
2. the physical workstation proves Arc B580/`xe`, Vulkan renderer, GNOME/Wayland, 2560×1440/~240 Hz and the enabled Gaming payload.

A first real game launch remains an operator acceptance test rather than a CI assertion, because game binaries, Steam authentication, anti-cheat support and title-specific Proton compatibility are external runtime variables.

## What is deliberately excluded

The Golden Gaming profile does not:

- replace Fedora's kernel with a gaming-tuned kernel;
- add Mesa git/COPR or vendor GPU repositories;
- apply persistent `sysctl`, scheduler or CPU-governor hacks globally;
- force Gamescope or MangoHud for every title;
- force Proton-GE globally;
- install Heroic/Lutris/Wine in the initial Steam foundation.

Heroic and Lutris can be evaluated later as optional launcher integrations after the Steam/Proton foundation is certified on bare metal.
