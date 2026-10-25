# ReBroad APT repository (experimental)

This fork's signed Termux APT repository is an independent, static feed:

```
https://raw.githubusercontent.com/rebroad/termux-packages/apt-repo
```

The package index is signed with a **dedicated OpenPGP archive key**, not an
Android APK certificate. Full fingerprint:

```
D707B230D33E2AA09C0B979FAC3209C81372E53A
```

The feed initially has no packages until an Android aarch64 sccache build
passes and its signing secrets are provided. **Do not use `trusted=yes` or
`allow-unauthenticated` to bypass APT signatures.**

## Enable repository and preference

On a Termux aarch64 installation, run:

```bash
curl -fsSL https://raw.githubusercontent.com/rebroad/termux-packages/master/scripts/rebroad-enable-repo.sh -o /tmp/rebroad-enable-repo.sh
bash /tmp/rebroad-enable-repo.sh
```

The script validates the public key with a pinned SHA256, installs a scoped
`signed-by` APT source, and writes `Pin: release o=ReBroad` with priority
`1001` into `$PREFIX/etc/apt/preferences.d/00-rebroad`. This makes matching
versions from the ReBroad feed override official Termux mirror versions,
including when the official version is newer. **Other repositories stay
enabled** and APT falls back to them when ReBroad has no matching package.

Inspect candidate selection with `apt-cache policy sccache`. Disable override
by removing `00-rebroad`, and remove `rebroad.list` to disable the feed.

## Source and package

The `sccache` recipe builds the pinned Git revision
`1570d050233a77718c24ba0e27d702760adc01f4` from the
`rebroad/sccache` branch `rust-incremental-snapshots`.
Version `0.18.0+rebroad1`; the branch contains experimental Rust incremental
snapshot support. Linux x86_64 test results are not evidence of native Android
runtime compatibility or improved performance. A native Termux binary must be
built and smoke-tested first.

Build artifacts are published by GitHub Actions, but **APT publication requires
two repository-level GitHub Actions secrets** in `rebroad/termux-packages`:
`REBROAD_APT_GPG_PRIVATE_KEY` (complete ASCII-armored secret key) and
`REBROAD_APT_GPG_PASSPHRASE` (its passphrase). Never commit either secret. The
workflow verifies the expected public fingerprint before signing `InRelease`.
The dedicated `apt-repo` branch is the public, **signed** package index and
binary storage. Hosted on GitHub raw files; GitHub caches content briefly and
large .deb blobs cannot exceed GitHub's normal repository file-size limits.

This repository supports `aarch64` first. Expanding to `arm`, `i686`,
and `x86_64` requires separately built packages and signed indexes.
