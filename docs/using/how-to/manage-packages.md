# Manage packages

Everything installable in Nodos is a **package**: plugins, subsystems, engines, SDKs, and generic
artifacts. `nodos` installs them from the Nodos Store into the current workspace.

All commands here run from a workspace root. Full flag listings are in the
[nodos CLI reference](../reference/nodos-cli.md).

## Find something to install

```shell
nodos list --store
```

Narrow to one package's versions:

```shell
nodos list --store --package-name nos.sys.vulkan
```

See what is already in the workspace:

```shell
nodos list --local
```

## Install a package

```shell
nodos install nos.sys.vulkan 8.0
```

The version argument is a **minimum within a minor line**, not an exact pin. `8.0` means "any
`8.0.x`, and if none is installed, fetch the latest `8.0.x`". This is usually what you want, since
patch releases within a minor version are compatible.

To pin exactly:

```shell
nodos install nos.sys.vulkan 8.0.0 --exact
```

Dependencies are resolved and installed too. `--without-deps` skips that, which is occasionally
useful when you are managing versions by hand and rarely otherwise.

By default packages land in `<package_type>/Downloaded/<name>/<version>`. Override with
`--out-dir` and `--prefix` if you need a specific layout.

## Inspect a package

```shell
nodos info nos.sys.vulkan 8.0
```

This prints JSON, so it composes with other tooling:

```shell
nodos info nos.sys.vulkan 8.0 | jq -r '.binary_path'
```

Add `--relaxed` to accept any version within the given minor line rather than requiring an exact
match.

To inspect an SDK rather than a module:

```shell
nodos sdk-info {{ nodos_version }}.0 plugin
```

The second argument is one of `engine`, `plugin`, `subsystem` or `process`. This is the command to
use in a build system that needs an SDK's include directory — see
[Connect an external application](../../developing/how-to/connect-an-external-app.md).

## Remove a package

```shell
nodos remove nos.sys.vulkan 8.0.0
```

Removal requires an exact version, because a workspace can legitimately hold several.

## Refresh the index

After adding, removing or editing modules on disk by hand, the workspace index goes stale:

```shell
nodos rescan
```

Commands that look up node classes or package metadata read this index, so run it whenever the
filesystem and the index might have diverged.

## Bundles

`nodos get` fetches an engine bundle rather than an individual package:

```shell
nodos get --name nodos.bundle.ai --version {{ nodos_version }}
```

!!! warning
    This replaces the workspace's Nodos release and removes all installed engines. Use
    `--clean-modules` to also clear modules, and `-y` to skip the confirmation prompt.

Available bundles are listed in [Install Nodos](install-nodos.md#bundles).

## Authenticate for private packages

Public packages need no authentication. Private ones — restricted to your namespace or explicitly
granted accounts — need a token:

```shell
nodos auth login
```

This uses a device flow: it prints a code, you approve it in a browser. The token persists in the
workspace until:

```shell
nodos auth logout
```

## Add a dependency to your own package

To record that your plugin depends on another module, edit its manifest, or let the CLI do it:

```shell
nodos depend mycorp.myplugin nos.sys.vulkan-8.0
```

The version suffix is optional. See
[Depend on another module](../../developing/how-to/depend-on-another-module.md) for the C++ side, which is the part that
actually matters.
