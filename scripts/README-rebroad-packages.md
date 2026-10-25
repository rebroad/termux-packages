# ReBroad package updates

The list in `scripts/rebroad-upstream-packages.json` is the source of truth for packages built and staged in the ReBroad APT feed.

## Add a package

1. Add its Termux recipe under `packages/<name>/build.sh`.
2. Add one manifest entry with the package name, GitHub repository, branch to track, current source commit, and version prefix.
3. Make the recipe pin that source commit in `termux_step_post_get_source`. Keep one `TERMUX_PKG_VERSION` assignment; the updater refreshes both values together.

The scheduled `Refresh ReBroad package sources` workflow checks each listed branch daily and opens or updates one PR when a source commit changes. The package CI must pass before merging. After merge, `Build and stage ReBroad Termux packages` builds every listed package for aarch64 and stages the resulting .debs in `apt-repo/pool`.

The package staging workflow intentionally follows the existing feed process: it commits binaries to the pool. Updating `Packages`, `Release`, `InRelease`, and `Release.gpg` is a separate signing step. Run `scripts/rebroad-publish-apt.sh` from the apt-repo worktree with the new package artifacts and the existing archive signing credentials; it reads the same manifest and regenerates the signed index for every listed package.
