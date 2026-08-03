# nodos CLI

`nodos` (built from `Toolchain/nosman`) is the Nodos workspace and package manager. It installs
packages, scaffolds modules, drives builds, launches the engine, and publishes to the Nodos Store.

Describes nosman 0.17.

```plaintext
nodos [OPTIONS] [COMMAND]
```

## Global options

`-w, --workspace <workspace>`
:   Directory of the workspace to operate on. Default `.`.

`--silently-agree-eula`
:   Agree to the Nodos EULA without prompting. Agrees for every installed engine.

`-h, --help [<help>]`
:   Print help, optionally for a named command.

`-V, --version`
:   Print the version.

---

## Workspace

### `nodos init`

Initialise the current directory as a Nodos workspace.

`--allow-nested`
:   Allow creating a workspace inside another workspace.

`--reinit`
:   Reinitialise if a workspace already exists here.

### `nodos deinit`

Deinitialise a Nodos workspace.

### `nodos rescan`

Rescan packages and update caches. Run after changing modules on disk by hand — commands that
resolve packages or node classes read this index.

---

## Packages

### `nodos install <package> [version]`

Install a package.

`--exact`
:   Treat `version` as exact. Without it, `version` is a minimum within its minor line: for `a.b`,
    the newest installed `x` with `a.b <= x < a.(b+1)` is used, or the latest such version is
    fetched. Fails if `version` is `latest` or has no minor component.

`--without-deps`
:   Do not install the package's dependencies.

`--prefix <prefix>`
:   Folder path relative to `--out-dir`. Default `<package_name>/<version>`.

`--out-dir <out_dir>`
:   Installation directory. Default `<package_type>/Downloaded`.

### `nodos remove <package> <version>`

Remove a package. The version must be exact.

### `nodos list`

List packages.

`--local`
:   List local packages.

`--store`
:   List packages from the Nodos Store.

`-p, --package-name <package_name>`
:   List versions of one package.

### `nodos info [package] [version]`

Print information about an installed package as JSON. Errors if not installed.

`--relaxed`
:   Interpret `version` as a minimum within its minor line rather than an exact match.

`--manifest <manifest>`
:   Read from a manifest path instead of a package name.

### `nodos sdk-info <version> [sdk-type]`

Print information about an installed SDK. Errors if the version is not present.

`sdk-type`
:   One of `engine`, `plugin`, `subsystem`, `process`. Default `engine`.

### `nodos get`

Bring a Nodos release into the workspace, or update an existing one. Aliased as `nodos update`.

!!! warning
    Updating removes **all installed Nodos engines** in the workspace.

`--name <name>`
:   Release name — `nodos`, or a bundle. Default `nodos.bundle.standard`.

`-v, --version <version>`
:   Release version. Defaults to `1.3`, an older line — pass `{{ nodos_version }}` for the current
    one.

`-y`
:   Do not prompt; take the default action.

`--clean-modules`
:   Remove Nodos modules before installing.

---

## Authoring

### `nodos create <name> [type]`

Create a Nodos plugin.

`type`
:   `plugin` or `subsystem`. Required only for Nodos versions before {{ nodos_version }} — from
    {{ nodos_version }} the `.nosplugin` manifest covers both.

`-l, --language-tool <language/tool>`
:   Default and only current value `cpp/cmake`.

`-o, --output-dir <output_dir>`
:   Where to create the plugin folder. Default `./Module`.

`--prefix <prefix>`
:   Folder path relative to the output directory. Default `<plugin_name>`.

`-y, --yes-to-all`
:   Do not prompt; use defaults for missing parameters.

`--description <description>`
:   Plugin description.

`-d, --dependency <dependency>`
:   Add a dependency as `<plugin_name>-<version>`. Repeatable.

`-n, --nodos-version <VERSION>`
:   Nodos version to target. Defaults to the latest.

### `nodos node <plugin> <node_class_name>`

Add or remove a node definition in a plugin.

`--remove`
:   Remove the node class. Removes the file too if it held only that node.

`--display-name <display_name>`
:   Display name.

`--description <description>`
:   Description.

`--category <category>`
:   Menu category.

`--hide`
:   Set `hide_in_context_menu` so editors omit it from the right-click menu.

`-n, --nodos-version <VERSION>`
:   Nodos version to write the definition for. Defaults to the line the plugin's own manifest
    targets.

### `nodos pin <node_class_name> <pin_name>`

Add or remove a pin on a node definition. Omitted parameters are prompted for interactively.

`--remove`
:   Remove the pin.

`--show-as <show_as>`
:   `INPUT_PIN`, `OUTPUT_PIN` or `PROPERTY`.

`--can-show-as <can_show_as>`
:   `PROPERTY_ONLY`, `INPUT_PIN_ONLY`, `INPUT_PIN_OR_PROPERTY`, `OUTPUT_PIN_OR_PROPERTY`,
    `OUTPUT_PIN_ONLY`, `INPUT_OUTPUT`, `INPUT_OUTPUT_PROPERTY`.

`--type-name <type_name>`
:   Pin data type.

Defaults and ranges are not exposed as flags; set those by editing the definition file. See
[Add nodes and pins](../../developing/how-to/add-nodes-and-pins.md).

### `nodos depend <package> [dependency]...`

Add dependencies to a package. Format `<package_name>-<version>`; the version is optional.
Repeatable.

### `nodos get-sample <name> --output-dir <output_dir>`

Fetch a sample implementation. `name` is `vk_app` or `dx12_app`.

---

## Development

### `nodos dev gen [extra_args]...`

Generate project files for plugin development. Extra arguments are forwarded to the underlying
tool.

`-l, --language-tool <language/tool>`
:   Default `cpp/cmake`.

`-p, --project-folder <project_folder>`
:   Output folder. Default `Project`.

`--rm-cache`
:   CMake only. Remove `CMakeCache.txt` before generating.

`--clean`
:   CMake only. Delete the output directory before generating.

`--plugin-dirs [<plugin_dirs>]`
:   Generate only for these plugin directories. Use for plugins outside the workspace.

### `nodos dev build [extra_args]...`

Build generated project files. Extra arguments are forwarded to the build tool.

`-l, --language-tool <language/tool>`
:   Default `cpp/cmake`.

`-p, --project-folder <project_folder>`
:   Project folder to build. Default `Project`.

`--config <config>`
:   CMake only. Build configuration, e.g. `Debug`, `Release`.

`--target <target>`
:   CMake only. Build a single target.

`--clean-first`
:   CMake only. Clean before building.

`--verbose`
:   CMake only. Verbose output.

`-j, --jobs <job_count>`
:   Parallel jobs. Default `auto`.

### `nodos dev setup`

Clone Nodos repositories from the `nodos-dev` organisation recursively into the workspace, skipping
any already present. Only repositories your account can access are cloned.

`-m, --directory <dir>`
:   Directories to scan. Default `. Engine Module`.

`--ssh`
:   Clone over SSH rather than HTTPS.

`-a, --all`
:   Clone all missing repositories without prompting.

### `nodos dev pull`

Scan for git repositories under the workspace and pull their current branches.

### `nodos dev status`

Show the status of git repositories under the workspace.

### `nodos dev init`

Initialise development toolchain files under the workspace.

### `nodos test`

Enumerate plugins in a folder, look under each plugin's `Tests/` folder, and run `nosLauncher
--load-graph` for every graph file found (`.nos` and `.nosa`).

`-p, --plugins-folder <plugins_folder>`
:   Folder containing plugins. Default: workspace root.

`-e, --engine-dir <engine_dir>`
:   Engine directory to use. Default: auto-detected from the workspace.

`-t, --timeout <timeout>`
:   Timeout in seconds per test. Default `30`.

---

## Running

### `nodos launch [engine]`

Launch Nodos. Alias of `nodos engine launch`.

`engine`
:   Name or version of the engine. If omitted and several are installed, you are asked to pick.

### `nodos engine <COMMAND>`

Manage the local engine.

| Command | Effect |
|---|---|
| `launch` | Launch Nodos. |
| `list` | List engines installed in this workspace. |
| `stop` | Stop the running engine and editor for this workspace. |
| `status` | Show whether the engine and editor are running. |
| `restart` | Stop the running instance if any, then launch again. |

---

## Store

### `nodos auth <COMMAND>`

| Command | Effect |
|---|---|
| `login` | Log in to the Nodos Store via device flow. |
| `logout` | Remove the stored access token. |

### `nodos publish`

Publish a package to the Nodos Store.

`-p, --path <path>`
:   Root folder (or file) of the package. Default `.`. Without a `.nospub` file in the folder,
    **all files are added to the release**.

`-n, --name <name>`
:   Package name. Overridden by a manifest under `--path`. Required when there is none.

`--version <version>`
:   Package version. Overridden by a manifest. Required when there is none.

`--version-suffix <version_suffix>`
:   Suffix appended to the version.

`-t, --type <type>`
:   `plugin`, `subsystem`, `nodos`, `engine` or `generic`. Overridden by a manifest.

`--dry-run`
:   Show what would be done without publishing.

`--verbose`
:   Print more detail.

`--tag <tag>`
:   Add a release tag. Repeatable.

`--target-platform <target_platform>`
:   Target architecture and OS. Defaults to the current platform.

`--changelog <changelog>`
:   Release notes. Falls back to `CHANGELOG.md` in the package directory, then to a store-generated
    changelog from the artifact diff.

`--visibility <visibility>`
:   `public` (default) or `private`, applied on first publish only. Ignored if the package already
    exists — change visibility from the Store dashboard.

`--no-tag`
:   Do not create a `release-<name>-<version>-<target>` git tag after publishing.

`--no-push-tag`
:   Create the tag locally but do not push it.

`--no-fetch-tags`
:   Do not fetch tags or unshallow the repository before generating the changelog. By default
    nosman does, so changelog generation works under CI's shallow checkouts.

### `nodos publish-batch`

Publish all — or only changed — packages under the git repository.

### `nodos unpublish`

Unpublish a package version from the Nodos Store. Consumers pinned to that version can no longer
resolve it.
