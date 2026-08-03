# Subsystems

A **subsystem** is a module that exposes a C API for other modules to call, rather than (or as well
as) contributing nodes. Where a plugin adds nodes to the graph, a subsystem adds capability to
other modules.

On Nodos {{ nodos_version }} there is no structural difference between the two: both use a
`.nosplugin` manifest, and `nodos create` produces the same scaffold. The distinction is what the
module is *for*.

!!! warning "Nodos {{ legacy_version }}"
    Subsystems used a `.nossys` manifest and had to be created with `nodos create <name> subsystem`.

## Using a subsystem

Three steps, covered in
[Depend on another module](../../how-to/depend-on-another-module.md):

1. Declare it in your manifest's `info.dependencies`.
2. Import it — `NOS_DEPENDENCY(...)` on {{ nodos_version }}, `nosEngine.RequestSubsystem` on
   {{ legacy_version }}.
3. Check availability. The requested version may not be installed.

## Documented subsystems

- [`nos.sys.vulkan`](nos.sys.vulkan.md) — GPU resources, command recording, shaders and passes.

## Other subsystems

These ship with various bundles and are not yet documented here. Inspect any of them with
`nodos info <name> <version>`, and read their public headers under
`Include/<ModuleName>/`.

| Module | Purpose |
|---|---|
| `nos.sys.shaderc` | Shader compilation. |
| `nos.sys.settings` | Module settings storage. |
| `nos.sys.device` | Device enumeration and management. |
| `nos.sys.ai` | AI runtime services. |
| `nos.sys.cuda` | CUDA interop. |
| `nos.sys.tensor` | Tensor types and conversion. |
| `nos.sys.decklink` | Blackmagic DeckLink device access. |

## Writing a subsystem

Fill in the API struct in the scaffolded public header
`Include/<CamelCase>/<CamelCase>.h`, and populate it from the `OnRequestAPI` callback in your
plugin functions.

The scaffold already generates the three macros consumers need:

```cpp
#define MYSUBSYSTEM_NAME "mycorp.mysubsystem"
#define MYSUBSYSTEM_INIT()    /* defines the global API pointer */
#define MYSUBSYSTEM_IMPORT()  /* imports it via NOS_IMPORT_DEP */
```

Consumers then write `NOS_DEPENDENCY(MYSUBSYSTEM)` in their `NOS_DEPENDENCIES` list.

Because that header *is* your API contract, version it accordingly: any change to the struct layout
or function signatures is a major version bump. See
[Versioning and SDK lines](../../explanation/versioning.md).
