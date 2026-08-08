# cc-switch-cli-musl-bin

Arch User Repository packaging for the static MUSL release of
[cc-switch-cli](https://github.com/SaladDay/cc-switch-cli).

This is intentionally a separate variant from `cc-switch-cli-bin`: it uses
the upstream `linux-x64-musl` and `linux-arm64-musl` deliverables and
conflicts with packages that install the same `cc-switch` command.

The GitHub Actions workflow checks the upstream stable release every six
hours. When a release appears, it updates `PKGBUILD` and `.SRCINFO`, verifies
the source checksums, builds the package in Arch Linux, commits the update to
this repository, and synchronizes the package to the AUR.

One-time setup for AUR synchronization:

1. The AUR account used by the workflow must own or be authorized to push to
   the `cc-switch-cli-musl-bin` package.
2. Add the matching AUR private key as the repository secret
   `AUR_SSH_PRIVATE_KEY`.

The workflow loads that secret directly into `ssh-agent` through standard
input. It never commits, prints, or writes the private key to the repository.
