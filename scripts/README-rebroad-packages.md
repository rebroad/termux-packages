# ReBroad package updates

The list in `scripts/rebroad-upstream-packages.json` is the source of truth for packages built and published in the ReBroad APT feed.

## Add a package

1. Add its Termux recipe under `packages/<name>/build.sh`.
2. Add one manifest entry with the package name, GitHub repository, branch to track, current source commit, and version prefix.
3. Make the recipe pin that source commit in `termux_step_post_get_source`. Keep one `TERMUX_PKG_VERSION` assignment; the updater refreshes both values together.

The scheduled `Refresh ReBroad package sources` workflow checks each listed branch daily. When a source commit changes, it updates the recipe pin and version, builds and validates changed packages for aarch64, commits the recipe updates to `master`, and dispatches `Build and stage ReBroad Termux packages`. That workflow builds every listed package, replaces the packages in `apt-repo/pool`, regenerates and signs the APT index, and pushes the binaries and index to `apt-repo`. The process is automatic after the recipe and manifest are configured; no manual merge or signing step is needed.

For a manual publication, run `scripts/rebroad-publish-apt.sh` from an `apt-repo` worktree with the built package directory in `PACKAGE_DIR` and the archive signing key in `REBROAD_APT_GPG_PRIVATE_KEY`. Set `REBROAD_APT_GPG_PASSPHRASE` only if the key has a passphrase. The script validates the key fingerprint and package set before writing the signed index.
