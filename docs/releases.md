# Publishing Conjuror

Publish releases in `conjuror-app/conjuror`. The `conjuror-app/releases`
repository retains historical downloads and feedback links for older apps.

1. Update the app version, build number, and `CHANGELOG.md`. Run `make lint`
   and `make test`, then commit the release changes.
2. Create and push a source tag for that commit, such as `1.0.0-alpha.17`.
   Build from that tagged commit with a clean working copy.
3. Build and notarize using the configured Developer ID signing identity and
   the `conjuror-notary` keychain profile:

   ```fish
   make archive
   make notarize
   make zip
   ```

4. Put the release notes in a file outside the repository. Publish the app and
   matching symbols using the exact paths printed by `make zip`:

   ```fish
   ./scripts/publish-release.sh 1.0.0-alpha.17 /tmp/conjuror-release-notes.md builds/conjuror-1.0-alpha.17.zip builds/conjuror-1.0-alpha.17.dSYM.zip
   ```

   The script requires an existing remote tag, uploads both assets as a draft,
   then publishes it. Tags containing a hyphen are marked as prereleases.
   If uploading or publishing fails, inspect the draft before retrying. The
   script does not overwrite an existing release.

5. Download the published app ZIP and compare its SHA-256 with the local file.
   Check installation and launch on macOS. Update the website's download URL,
   release URL, and display name, and update the Homebrew cask's version, URL,
   and SHA-256.

Source tags and archive filenames are separate. Historical source tags use
`1.0.0-alpha.N`, while their archives use `1.0-alpha.N` or `1.0-N`. Preserve
the actual filenames. Use explicit release URLs for alphas; GitHub's
`/releases/latest` shortcut excludes prereleases.
