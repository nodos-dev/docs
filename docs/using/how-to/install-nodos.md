# Install Nodos

Nodos is installed in two stages: first `nodos`, the workspace and package manager; then an engine
release, fetched into a workspace.

## Requirements

| | |
|---|---|
| **OS** | Windows 10 or later on x86_64. Linux x86_64 and macOS work but are not yet released. |
| **GPU** | A driver supporting Vulkan 1.2. |
| **Windows runtime** | Microsoft Visual C++ Redistributable. The installer offers to install it. |

Additionally, if you intend to build plugins:

| | |
|---|---|
| **CMake** | 3.24.2 or newer. |
| **Compiler** | A {{ cpp_version }}-capable toolchain and a CMake generator for it. |
| **git** | Used by the `nodos dev` commands and by publishing. Both installers offer to fetch it. |
| **Rust** | Only if you want to build `nosman` itself from source. |

## Install the package manager

=== "Windows (PowerShell)"

    ```powershell
    irm https://nodos.dev/install.ps1 | iex
    ```

    The script checks for the Visual C++ Redistributable and installs it from Microsoft's official
    redistributable installer. It also offers `git` through `winget` — Nodos itself does not need
    it, so decline if you are not going to build plugins.

=== "Linux"

    ```bash
    curl -fsSL https://nodos.dev/install.sh | bash
    ```

    The script offers `git` through whichever package manager it detects. Nodos itself does not
    need it, so decline if you are not going to build plugins.

Both installers fetch the latest `nosman` release, and offer to fetch a Nodos release at the same
time.

Verify:

```shell
nodos --version
```

Running `nodos` with no arguments prints the command list.

## Create a workspace

A **workspace** is a directory that Nodos manages: engine, modules, downloaded packages and
generated projects all live inside it. Workspaces are self-contained, so you can keep several side
by side at different versions.

```shell
mkdir MyNodos
cd MyNodos
nodos init
```

??? note "Nesting and re-initialising"
    `nodos init` refuses to create a workspace inside another one. Pass `--allow-nested` if that is
    genuinely what you want, or `--reinit` to reinitialise the current directory.

## Fetch an engine

```shell
nodos get --name nodos.bundle.standard --version {{ nodos_version }}
```

You must accept the EULA on first run. To accept non-interactively — in CI, for example — use
`nodos --silently-agree-eula`.

!!! warning
    `nodos get` updates the Nodos release in the workspace, and doing so **removes all installed
    engines** in it. Add `--clean-modules` if you also want modules removed.

### Bundles

A bundle is an engine plus a preinstalled module set.

| Bundle | Contents |
|---|---|
| `nodos.bundle.minimal` | Engine and the smallest usable module set. |
| `nodos.bundle.standard` | General-purpose default. |
| `nodos.bundle.broadcast` | Video I/O, DeckLink, timecode, broadcast workflows. |
| `nodos.bundle.ai` | ONNX, tensor, CUDA and AI model nodes. |
| `nodos.bundle.full` | Everything, including AI and broadcast. |

Pick the smallest one that covers your work; anything missing can be installed later with
[`nodos install`](manage-packages.md).

## Launch

```shell
nodos launch
```

This starts `nosLauncher` (which hosts the engine and runs graphs) and `nosEditor` (the UI). If the
workspace has several engines installed, you will be asked which to launch, or you can name one:

```shell
nodos launch 1.4.0
```

Manage a running instance with:

```shell
nodos engine status
nodos engine restart
nodos engine stop
nodos engine list
```

## Where things end up

```plaintext
MyNodos/
├── .nosman/          # workspace index and remote metadata
├── Engine/           # engine installs, one folder per version
├── Module/           # your plugins and subsystems, plus Downloaded/ for fetched ones
├── Package/          # downloaded SDKs and generic packages
├── Toolchain/        # CMake entry point and helpers
└── Project/          # generated CMake project — disposable, regenerate freely
```

[Workspace layout](../../developing/reference/workspace-layout.md) describes each of these in detail.

## Next

- [Your first graph](../tutorials/your-first-graph.md)
- [Manage packages](manage-packages.md)
