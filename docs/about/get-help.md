# Get help

## Where to ask

- **[Discord](https://discord.gg/jcgEWFYQn5)** — the Nodos community server. Fastest route for
  "is this supposed to work like this?" questions.
- **GitHub** — [github.com/nodos-dev](https://github.com/nodos-dev). File issues against the
  repository that owns the problem:

    | Problem in | Repository |
    |---|---|
    | The `nodos` CLI, workspace or build toolchain | `nodos-dev/workspace` |
    | A shipped module or node | That module's repository, e.g. `nodos-dev/modules`, `nodos-dev/sys-vulkan` |
    | These docs | `nodos-dev/docs` |
    | The engine, editor or launcher | `nodos-dev/workspace` — engine development is not public, but reports are read and triaged there |

- **Email** — [contact@nodos.dev](mailto:contact@nodos.dev) for licensing and commercial questions.

## Collect the right information first

A report is far more useful with these attached.

### Versions

```shell
nodos --version
nodos engine list
nodos list --local
```

### Logs

Engine and launcher logs are written under the engine install:

```plaintext
Engine/<version>/Logs/
```

Reproduce the problem, then attach the most recent log file. The editor's **Log** pane shows the
same stream live, which is usually where a failing node explains itself — node status messages and
plugin errors both land there.

### The graph

If a specific graph misbehaves, save it and attach the file. Graphs are self-contained and
reproduce reliably, which shortens diagnosis considerably.

## Common problems

### A node does not appear in the right-click menu

Check, in order:

1. Is the module loaded? The **Modules** pane lists loaded modules; click **Fetch** then **Load**.
2. Does the node's `class_name` in its `.nosnode` match the name passed to
   `NOS_BIND_NODE_CLASS` exactly, including the namespace prefix?
3. Is `hide_in_context_menu` set to `true` in its `menu_info`?

### "Plugin is trying to register a node that doesn't exist in its node definitions"

The C++ side registered a node class the engine has no definition for. Either the `.nosnode` file
is missing, or its `class_name` does not match the string in `NOS_BIND_NODE_CLASS`.

### The graph does nothing

A graph only executes along paths that reach a sink and originate at a thread. A node with no path
to a sink is never scheduled. See
[Scheduling and execution](../using/explanation/scheduling.md).

### A subsystem request fails

`nosEngine.RequestSubsystem` returns a failure when the requested subsystem is not present at a
compatible version. Always check its result — see
[Depend on another module](../developing/how-to/depend-on-another-module.md).

### The build cannot find the SDK

`nodos dev gen` fetches SDKs declared by `sdk_version` in each manifest. If it cannot, check
network access to the Nodos Store and that the version in the manifest exists:

```shell
nodos list --store --package-name nodos.sdk.plugin
```

## Contributing a fix

Documentation and module sources are open. See [Contributing](contributing.md).
