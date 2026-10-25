# ReBroad APT repository (experimental)

This fork's signed Termux APT repository is an independent, static feed:

```
https://raw.githubusercontent.com/rebroad/termux-packages/apt-repo
```

The package index is signed with a **dedicated OpenPGP archive key**, not an
Android APK certificate. Full fingerprint:

```
1ED97E796A59F08B22CE7CACFFF9DB83A50BE6C9
```

The feed now contains a signed Android aarch64 `sccache` package. The public
key was rotated on 25 October 2026 when the original private signing key was
unavailable. Existing installations must refresh the ReBroad public key using
the setup script below before running `pkg update` or `pkg install`. **Do not use `trusted=yes` or
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
runtime compatibility or improved performance. The native Termux ARM64 binary is built and published, but its runtime behavior
has not yet been smoke-tested on an actual Android device.

A one-time signed APT index was published using the rotated key.
**Future automated APT publication requires two repository-level GitHub Actions secrets** in `rebroad/termux-packages`:
`REBROAD_APT_GPG_PRIVATE_KEY` (complete ASCII-armored secret key) and
`REBROAD_APT_GPG_PASSPHRASE` (its passphrase). Never commit either secret. The
workflow verifies the expected public fingerprint before signing `InRelease`.
The dedicated `apt-repo` branch is the public, **signed** package index and
binary storage. Hosted on GitHub raw files; GitHub caches content briefly and
large .deb blobs cannot exceed GitHub's normal repository file-size limits.

## Package available now

- Signed APT index: [apt-repo](https://github.com/rebroad/termux-packages/tree/apt-repo/dists/stable)
- Direct .deb release: [sccache 0.18.0+rebroad1](https://github.com/rebroad/termux-packages/releases/tag/sccache-0.18.0-rebroad.1-aarch64)
- Binary SHA256: `5bd444388daecc327aa1bb311d3b94dfa49b55ad0b96df9f729796b7f6ce8e74`

Run the repository setup script again when upgrading a pre-key-rotation
installation. Then run `pkg update`, `apt-cache policy sccache`,
`pkg install sccache`, and `sccache --version`. The policy should show
`0.18.0+rebroad1` as the selected candidate at priority 1001.

### Signing-key custody

The original OpenPGP private key is not available for continued signing. A
replacement archive key is stored outside Git, and its public half is included
in `apt-repo` and the companion Termux bootstrap. For automated future
publishing, store the **matching replacement private key** as the
`REBROAD_APT_GPG_PRIVATE_KEY` GitHub Actions secret and its passphrase as
`REBROAD_APT_GPG_PASSPHRASE`. GitHub repository Settings → Secrets and
variables → Actions is the supported manual setup location. Do not publish
these secrets in source, logs, or issues. The publisher rejects any private
key not matching fingerprint `1ED97E796A59F08B22CE7CACFFF9DB83A50BE6C9`. Losing this key again
would require another key rotation, APK rebuild, and user key refresh.

This repository supports `aarch64` first. Expanding to `arm`, `i686`,
and `x86_64` requires separately built packages and signed indexes.
