# Developing for Nodos

Extending Nodos: plugins and subsystems that add node types, and external applications that join a
graph over the network.

!!! note "Start with the basics"
    These pages assume you can install Nodos and build a working graph. If you have not done that
    yet, go through [Using Nodos](../using/index.md) first — in particular
    [Your first graph](../using/tutorials/your-first-graph.md), which introduces the scheduling
    model your nodes will run inside.

There are three ways to extend Nodos, and picking the right one matters more than anything else
here. [Extension model](explanation/extension-model.md) covers the choice; the short version is
that a plugin is the default, and an application is what you use when the code cannot live in the
engine process.

## :material-school: Tutorials

- **[Your first plugin](tutorials/your-first-plugin.md)** — scaffold a plugin, define a node,
  implement it in C++, build it, and load it into the editor. Ends with your own node in the
  right-click menu. *About 30 minutes, needs a C++ toolchain.*

## :material-wrench: How-to guides

- **[Add nodes and pins](how-to/add-nodes-and-pins.md)** — extend an existing plugin with more node
  classes.
- **[Depend on another module](how-to/depend-on-another-module.md)** — declare, resolve and import
  another module's API.
- **[Write a shader-only node](how-to/write-a-shader-node.md)** — a GPU node with no C++ at all.
- **[Use the Vulkan subsystem](how-to/use-the-vulkan-subsystem.md)** — record GPU commands from a
  C++ node.
- **[Connect an external application](how-to/connect-an-external-app.md)** — make a separate
  process appear as a node using the Application SDK.
- **[Publish a package](how-to/publish-a-package.md)** — push a module to the Nodos Store, publicly
  or privately.
- **[Migrate a plugin to {{ nodos_version }}](how-to/migrate-1-3-to-1-4.md)** — move an older
  plugin onto the current manifest and build model.

## :material-book-open-variant: Reference

- **[Plugin manifest](reference/plugin-manifest.md)** — the `.nosplugin` file.
- **[Node definition](reference/node-definition.md)** — the `.nosnode` file: pins, visualizers,
  functions, presets.
- **[Plugin API (C++)](reference/plugin-api.md)** — `NodeContext` callbacks, entry point macros,
  engine services.
- **[Application SDK](reference/app-sdk.md)** — the out-of-process integration API.
- **[Built-in data types](reference/builtin-types.md)** — the types available to pins.
- **[Workspace layout](reference/workspace-layout.md)** — where modules, SDKs and generated
  projects live.
- **[Subsystems](reference/subsystems/index.md)** — including
  [`nos.sys.vulkan`](reference/subsystems/nos.sys.vulkan.md).

The [nodos CLI reference](../using/reference/nodos-cli.md) documents the authoring commands
(`create`, `node`, `depend`), the build commands (`dev gen`, `dev build`, `test`) and the store
commands (`publish`, `auth`) alongside the rest.

## :material-lightbulb-on: Explanation

- **[Extension model](explanation/extension-model.md)** — plugins, subsystems and applications, and
  how to choose between them.
- **[Objects and the type system](explanation/objects-and-types.md)** — why pin data is FlatBuffers,
  what an object reference is, and how resources stay alive.
- **[Versioning and SDK lines](explanation/versioning.md)** — engine, SDK and package versions are
  three different things; which one has to change, and when.

[Scheduling and execution](../using/explanation/scheduling.md) is filed under Using Nodos, but it is
required reading before you write `ExecuteNode` — it covers when your node is called, and why that
is not the same as when its inputs change.

## Conventions

- C++ constants are `SCREAMING_SNAKE_CASE`, not `kCamelCase`.
- Use `nos::ObjectRef` / `nos::TypedObjectRef` rather than raw `nosObjectId` or C resource structs.
- Adding a node means three things agreeing: the `.nosnode` `class_name`, the string passed to
  `NOS_BIND_NODE_CLASS`, and the `NOS_NODE(...)` entry. A mismatch is the usual reason a node does
  not appear.

Contributing to the modules that ship with Nodos: [Contributing](../about/contributing.md).
