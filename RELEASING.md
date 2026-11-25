# Releasing swift-java

This document is for maintainers: how swift-java's Java libraries get published
to Maven Central, the one-time setup that needs, and how to cut a release.

What gets published and how to depend on it is described in
[`PUBLISHING.md`](./PUBLISHING.md).

## How publishing works

[`.github/workflows/publish.yml`](.github/workflows/publish.yml) publishes
`swiftkit-core`, `swiftkit-ffm` and `swiftkit-native`:

| Trigger                                    | Version          | Published to                                             |
| ------------------------------------------ | ---------------- | -------------------------------------------------------- |
| Push to `main`                             | `X.Y.Z-SNAPSHOT` | https://central.sonatype.com/repository/maven-snapshots/ |
| Push of an `N.N.N` tag                     | `N.N.N`          | Maven Central                                            |
| Pull request changing the publishing setup | both             | nothing, [dry run](#dry-runs)                            |

Nothing is built or published until the full test suite passes on the commit:
the workflow first runs [`pull_request.yml`](.github/workflows/pull_request.yml)
as its `tests` job. Pull requests skip that job, since `pull_request.yml` already
runs on them. Before anything runs `./gradlew` with the secrets, the
`wrapper-validation` job checks `gradle/wrapper/gradle-wrapper.jar` against the
checksum Gradle publishes for the version in `gradle-wrapper.properties`. When
updating Gradle, run `./gradlew wrapper --gradle-version <version>` twice: the
first run only updates `gradle-wrapper.properties`, the second, now running the
new Gradle, also updates the jar. After that, all triggers run the same two jobs:

1. **`natives`** builds `libSwiftJava` and `libSwiftRuntimeFunctions` on every
   platform in its matrix (macOS arm64, Ubuntu 22.04 and 24.04 on x86_64 and
   arm64), and uploads them in a directory named after the platform's Maven
   classifier.
2. **`publish`** runs `./gradlew publishAllPublicationsToSonatypeRepository
   -PnativeLibsDir=natives`, which signs every module, with one `swiftkit-native`
   classifier jar per platform, and uploads it with Gradle's `maven-publish`. The
   version decides where it goes. A snapshot goes straight to the snapshots
   repository. A release goes to the Central Portal's OSSRH Staging API, and
   [`central-release.sh`](.github/scripts/central-release.sh) then turns it into
   a single deployment with `publishing_type=automatic` and waits until Central
   has validated it. Central publishes it right after, so no manual step in the
   Portal is needed.

To build with a newer Swift version, update `SWIFT_VERSION`, the `swift:X.Y-*`
container images and the Linux classifiers in `publish.yml`, and the classifier
table in `PUBLISHING.md`. To add a platform, add a matrix entry.

The Gradle side lives in:
- [`build.gradle.kts`](./build.gradle.kts): version computation
- [`build-logic.java-publishing-conventions`](BuildLogic/src/main/kotlin/build-logic.java-publishing-conventions.gradle.kts): POM metadata, signing, and the `staging` and `sonatype` repositories, applied by every published module
- [`SwiftKitNative/build.gradle.kts`](SwiftKitNative/build.gradle.kts): the per-platform classifier jars

### Dry runs

A dry run does everything a real publish does except the upload: it builds the
native libraries on every platform, publishes all artifacts with signatures and
checksums to `build/staging-deploy`, and checks every signature.

Pull requests that change the publishing setup (see the `pull_request` paths in
`publish.yml`) always dry-run. All
other runs are dry runs as well until publishing is enabled with the
`MAVEN_CENTRAL_PUBLISHING` repository variable, see
[Enabling publishing](#enabling-publishing). Without the real signing key, for
example in pull requests from forks, a dry run signs with a throwaway key.

### Re-running and skipped runs

A push to `main` whose commit is already tagged skips publishing, because the
run for the tag publishes it. To repeat a publish, for example after a
transient failure, run the workflow manually (**Actions → Publish → Run
workflow**) on `main` or on the release tag. Re-publishing a release that already
reached Maven Central fails, because releases are immutable.

## One-time setup

These steps need an account with access to the `org.swift.swiftjava` namespace
in the Sonatype Central Portal. Maintainers without Portal access only need the
repository secrets to be in place; releasing itself happens entirely through
git tags and the publish workflow.

### Maven Central credentials

In the Sonatype Central Portal at https://central.sonatype.com, click your
username, then **View Account**, then **Generate User Token**. The token's
username and password are used for both releases and snapshots.

The `org.swift.swiftjava` namespace must be verified in the Portal, and
**SNAPSHOTs must be enabled** for it (Namespaces → the namespace's menu →
Enable SNAPSHOTs), otherwise snapshot uploads are rejected.

### PGP signing key

Maven Central requires every artifact to be signed with a PGP key whose public
key is on a public keyserver. Use a dedicated key for swift-java releases, not a
personal one. A signing-only RSA key is all that's needed:

```bash
gpg --quick-gen-key 'swift-java release signing <EMAIL>' rsa4096 sign 3y   # asks for a passphrase
gpg --list-secret-keys --keyid-format=long 'swift-java release signing'   # sec   rsa4096/<KEY_ID> ...
gpg --armor --export <KEY_ID>             > public.asc
gpg --armor --export-secret-keys <KEY_ID> > private.asc   # still protected by the passphrase

# Maven Central verifies signatures against public keyservers
gpg --keyserver keyserver.ubuntu.com --send-keys <KEY_ID>
gpg --keyserver keys.openpgp.org      --send-keys <KEY_ID>
```

Before putting the key into GitHub, check that Gradle can sign with it, see
[Troubleshooting](#troubleshooting).

Keep `private.asc`, `public.asc` and the passphrase in the team's password
manager. GitHub secrets can't be read back, and every future release is signed
with this key. The key expires after the 3 years given above, see
[Rotating keys and tokens](#rotating-keys-and-tokens).

### Repository secrets

The publish workflow reads four repository secrets:

| Secret                               | Value                                                    |
| ------------------------------------ | -------------------------------------------------------- |
| `SONATYPE_USER`                      | Portal user token username                               |
| `SONATYPE_TOKEN`                     | Portal user token password                               |
| `ORG_GRADLE_PROJECT_SIGNINGKEY`      | Contents of `private.asc`, including the BEGIN/END lines |
| `ORG_GRADLE_PROJECT_SIGNINGPASSWORD` | The key's passphrase                                     |

Setting them needs admin access to the repository. Either add each one in
**Settings → Secrets and variables → Actions → New repository secret**, pasting
`private.asc` in full, from `-----BEGIN PGP PRIVATE KEY BLOCK-----` to
`-----END PGP PRIVATE KEY BLOCK-----`. Or use the GitHub CLI, which reads the
values from a file or prompts for them, so they don't end up in the shell
history:

```bash
gh secret set ORG_GRADLE_PROJECT_SIGNINGKEY      -R swiftlang/swift-java < private.asc
gh secret set ORG_GRADLE_PROJECT_SIGNINGPASSWORD -R swiftlang/swift-java   # prompts
gh secret set SONATYPE_USER                      -R swiftlang/swift-java   # prompts
gh secret set SONATYPE_TOKEN                     -R swiftlang/swift-java   # prompts
gh secret list -R swiftlang/swift-java
```

Don't paste the key material into chats, tickets or command lines.

How the workflow uses them:

- Only the `Publish` step of `publish.yml` gets the secrets, not the actions
  that run before it.
- GitHub stores secret names in upper case. The step passes the signing secrets
  on as the environment variables `ORG_GRADLE_PROJECT_signingKey` and
  `ORG_GRADLE_PROJECT_signingPassword`, which Gradle turns into the `signingKey`
  and `signingPassword` properties that
  [`build-logic.java-publishing-conventions`](BuildLogic/src/main/kotlin/build-logic.java-publishing-conventions.gradle.kts)
  signs with. `SONATYPE_USER` and `SONATYPE_TOKEN` are the credentials of the
  `sonatype` repository there.
- Pull requests from forks don't get secrets. Their dry runs sign with a
  throwaway key.
- These are the same secret names [ServiceTalk](https://github.com/apple/servicetalk)
  uses.

### Enabling publishing

Until the repository variable `MAVEN_CENTRAL_PUBLISHING` is set to `true`, the
publish workflow only does [dry runs](#dry-runs). To turn publishing on:

1. Verify the namespace, enable SNAPSHOTs and add the secrets, as described
   above.
2. Run the workflow manually on `main` (**Actions → Publish → Run workflow**).
   It's still a dry run, but now it signs with the real key and checks every
   signature, without uploading anything. The Portal credentials are only
   used by a real upload, so this doesn't check them.
3. Add the variable, in **Settings → Secrets and variables → Actions →
   Variables**, or with:

   ```bash
   gh variable set MAVEN_CENTRAL_PUBLISHING --body true -R swiftlang/swift-java
   ```

4. The next push to `main` publishes the first snapshot, which also checks the
   Portal credentials. Check that run before tagging a release.

Deleting the variable turns publishing off again.

### Rotating keys and tokens

- **The signing key expires**: extend it rather than making a new one, so users
  who already trust the key keep doing so. Then update the secret and the
  keyservers:

  ```bash
  gpg --quick-set-expire <KEY_ID> 3y
  gpg --armor --export-secret-keys <KEY_ID> > private.asc
  gh secret set ORG_GRADLE_PROJECT_SIGNINGKEY -R swiftlang/swift-java < private.asc
  gpg --keyserver keyserver.ubuntu.com --send-keys <KEY_ID>
  gpg --keyserver keys.openpgp.org      --send-keys <KEY_ID>
  ```

- **A new signing key**: update both `ORG_GRADLE_PROJECT_SIGNING*` secrets and
  publish the new public key to the keyservers. Earlier releases stay validly
  signed with the old key.
- **A new Portal user token**: update `SONATYPE_USER` and `SONATYPE_TOKEN`.

## Cutting a release

1. From a clean `main`, run `./scripts/release.sh`. It asks for the version,
   pins `swift-java-jni-core` to its latest release in `Package.swift`, checks
   that the Swift and Gradle builds pass, and pushes a `release/<version>` branch.
2. Open a pull request for that branch, qualify the release, and merge it.
3. Tag the merge commit on `main` and push the tag:

   ```bash
   git tag -s <version> -m <version>
   git push origin <version>
   ```

   This starts the publish workflow, which publishes `<version>` to Maven
   Central, or only dry-runs it while publishing isn't
   [enabled](#enabling-publishing). Follow it in the workflow run on GitHub:
   the `Publish` step uploads the artifacts, hands them to the Central Portal as
   a deployment, and polls the Portal until Central has validated it (up to 30
   minutes). If Central rejects the deployment, the run fails and prints
   Central's errors. Once published, it can take a while until the artifacts
   show up on https://central.sonatype.com and in Maven Central's search.
4. Create a GitHub release for the tag.
5. Run `./scripts/release.sh --next` (or press Enter in the still running script)
   to point `swift-java-jni-core` back at `main` for the next development cycle.

> **Releases are permanent.** A published version can't be changed or deleted.
> If something ships broken, fix it and release the next patch version.

## Troubleshooting

- Check what would be uploaded, without credentials (unsigned without a key):

  ```bash
  rm -rf build/staging-deploy
  ./gradlew publishAllPublicationsToStagingRepository
  find build/staging-deploy -type f
  ```

- Check that signing works with the real key, without uploading anything:

  ```bash
  export ORG_GRADLE_PROJECT_signingKey="$(gpg --armor --export-secret-keys <KEY_ID>)"
  read -rs ORG_GRADLE_PROJECT_signingPassword && export ORG_GRADLE_PROJECT_signingPassword   # type the passphrase
  rm -rf build/staging-deploy
  ./gradlew --no-daemon publishAllPublicationsToStagingRepository
  find build/staging-deploy -name '*.jar' -exec gpg --verify {}.asc {} \;
  ```
