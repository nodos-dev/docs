# Workspace layout

A Nodos **workspace** is a directory marked by a `.nosman` folder. Everything a Nodos installation
needs lives inside it, so workspaces are self-contained and several can coexist at different
versions.

```plaintext
MyNodos/
├── .nosman/          # workspace index and remote metadata
├── Engine/           # engine installs
├── Module/           # plugins and subsystems
├── Package/          # downloaded SDKs and generic packages
├── Project/          # generated build tree
├── Toolchain/        # CMake entry point and nosman sources
└── nodos             # the package manager binary (nodos.exe on Windows)
```

Create one with [`nodos init`](../../using/reference/nodos-cli.md#nodos-init).

## `.nosman/`

Workspace state.

| Path | Contents |
|---|---|
| `.nosman/index` | Local package index. Rebuilt by `nodos rescan`. |
| `.nosman/remote/<name>/index` | Cached remote index. |
| `.nosman/remote/<name>/releases/` | Release metadata per bundle, e.g. `nodos.bundle.standard.json`. |
| `.nosman/remote/<name>/presets/` | Bundle presets. |

Commands that resolve packages or node classes read the index, so run `nodos rescan` after editing
modules on disk by hand.

## `Engine/`

One folder per installed engine version. Inside an engine install:

| Path | Contents |
|---|---|
| `Binaries/` | `nosEngine`, `nosEditor`, `nosLauncher`, `libnosControl`, Vulkan loader. |
| `Config/` | `EngineSettings.json` and other engine configuration. |
| `Logs/` | Runtime logs. |
| `SDK/` | Built SDKs: `Plugin/`, `Process/`, `Types/`, `CMake/`, and `info.json`. |
| `Cache/` | Engine caches. |
| `EULA_CONFIRMED.json` | EULA acceptance state. |

`SDK/info.json` records the three version numbers that matter:

```json
{
	"version": "{{ nodos_version }}.0",
	"plugin_sdk_version": "{{ plugin_sdk_version }}.0",
	"process_sdk_version": "{{ process_sdk_version }}.0"
}
```

List installed engines with `nodos engine list`.

## `Module/`

Plugins and subsystems — both the ones you write and, under `Module/Downloaded/`, the ones fetched
from the store.

The toolchain scans this tree recursively (or `MODULE_DIRS`, if set). A folder containing exactly
one `.nosplugin` becomes a plugin target.

A module folder looks like:

```plaintext
mycorp.myplugin/
├── mycorp.myplugin.nosplugin
├── Binaries/        # build output
├── Include/         # public headers
├── Nodes/           # *.nosnode definitions, auto-discovered
├── Source/          # C++ implementation, globbed recursively
├── Types/           # *.fbs schemas
├── Tests/           # graph files for `nodos test`
└── CMakeLists.txt   # optional, additive
```

See [Plugin manifest](plugin-manifest.md).

## `Package/`

Downloaded SDKs and generic packages, under `Package/Downloaded/`:

```plaintext
Package/Downloaded/nodos.sdk.plugin/{{ plugin_sdk_version }}.0.bXXXX/
├── Binaries/     # flatc
├── CMake/        # FindnosPluginSDK.cmake
├── Include/      # SDK headers, including Nodos/
├── Libraries/
├── Template/     # scaffolding used by `nodos create`
└── Types/        # Builtins.fbs and the rest
```

Fetched automatically to satisfy the `sdk_version` declared in your manifests.

## `Toolchain/`

| Path | Contents |
|---|---|
| `Toolchain/CMake` | Workspace CMake entry point and helper scripts. |
| `Toolchain/nosman` | Sources for the `nodos` binary. Rust; only needed if you build it yourself. |

## `Project/`

The generated CMake build tree, produced by `nodos dev gen`.

!!! warning
    Disposable. Regenerate it; never hand-edit it. `nodos dev gen --clean` deletes and recreates it,
    which is the right move after changing anything structural.

Generate several side by side with `-p`:

```shell
nodos dev gen   -p Project14
nodos dev build -p Project14 --target nosMyPlugin
```

`Project/compile_commands.json` is generated too, so clangd and similar tools work without extra
setup.

## Workspaces spanning several repositories

When your modules live in more than one git repository under `Module/`, `nodos dev` operates across
all of them at once:

```shell
nodos dev status   # git status for every repository in the workspace
nodos dev pull     # pull current branches
```

`nodos dev setup` clones Nodos repositories from the `nodos-dev` organisation into the workspace,
skipping any already present. It can only clone repositories your account can access, so what it
fetches depends on your permissions.

To build a module that lives outside the workspace entirely, point the generator at it rather than
moving it:

```shell
nodos dev gen --plugin-dirs "/path/to/my/repo"
nodos dev build
```

## `.nospub`

Optional, at a package root. Restricts what `nodos publish` uploads:

```json
{
    "globs": [
        "/Binaries/**/*.{dll,so,dylib}",
        "/Nodes/**",
        "/Include/**",
        "/*.nosplugin"
    ]
}
```

Without it, **every file under the package path is published**. See
[Publish a package](../how-to/publish-a-package.md).
