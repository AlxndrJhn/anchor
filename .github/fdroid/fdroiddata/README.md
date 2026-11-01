# Anchor+ in F-Droid's own store

`com.alxndrjhn.anchorplus.yml` is Anchor+'s recipe for F-Droid's own store, to
send to https://gitlab.com/fdroid/fdroiddata as
`metadata/com.alxndrjhn.anchorplus.yml`. It is formatted as `fdroid rewritemeta`
writes it, so it goes there unchanged.

F-Droid builds it from source, without ML Kit (`mobile/tool/fdroid_prebuild.sh`)
and without the app's own updater (no `FORK_BUILD` / `UPDATE_REPO`), and signs
it with its own key: it can't update an Anchor+ installed from GitHub or from
the fork's F-Droid repositories, nor they it.

The builds are of a release tag `fork-<version>.<build>`. The version code is
the one the fork's release workflow gives it, 2000 + build, plus Flutter's
1000 × the processor type (armeabi-v7a 1, arm64-v8a 2, x86_64 4), and the
version name is the release's, with its commit. The builds are still of
`fork-0.18.0.69`, from before the app ID became `com.alxndrjhn.anchorplus`:
point them at the first release with it before sending the recipe. F-Droid sees newer tags, but someone adds
their builds to the recipe by hand (`AutoUpdateMode: None`): the build number
is in the build commands, not in the source.
