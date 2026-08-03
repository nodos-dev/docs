# Plugin manifest

A plugin manifest declares a module's identity, its dependencies, where its binary is, and which
SDK it was built against. It is the file the toolchain and the engine both read to decide what a
module is.

One extension, `*.nosplugin`, covers both plugins and subsystems. A folder containing exactly one
`.nosplugin` is treated as a plugin target by the toolchain, which scans `Module/` (or
`MODULE_DIRS`) recursively.

## Minimal manifest

```json
{
    "info": {
        "id": {
            "name": "mycorp.myplugin",
            "version": "0.1.0"
        },
        "display_name": "My Plugin",
        "description": "",
        "dependencies": []
    },
    "sdk_version": "{{ plugin_sdk_version }}"
}
```

## Complete example

```json title="Vulkan.nosplugin"
{
    "info": {
        "id": {
            "name": "nos.sys.vulkan",
            "version": "8.0.0"
        },
        "display_name": "Vulkan Subsystem",
        "description": "Graphics Subsystem for Nodos using Vulkan.",
        "dependencies": [
            { "name": "nos.sys.shaderc", "version": "2.1" },
            { "name": "nos.sys.settings", "version": "3.0" },
            { "name": "nos.sys.device",   "version": "2.0" },
            { "name": "nos.transfer",     "version": "0.1" }
        ],
        "category": "Graphics"
    },
    "defaults": [
        "Types/Defaults.json"
    ],
    "binary_path": "Binaries/nosSysVulkan",
    "third_party_software": ["Config/Licenses.json"],
    "sdk_version": "{{ plugin_sdk_version }}",
    "schema_version": "1.4-v1"
}
```

## Fields

### `info`

`info.id.name` — string, required
:   Globally unique package name. Dotted namespace convention: `<namespace>.<module>`, e.g.
    `nos.sys.vulkan`. This is the name used by `nodos install` and in other modules'
    `dependencies`.

`info.id.version` — string, required
:   Semantic version of this module. This is the version that gets published. Bump the major
    component on any API break.

`info.display_name` — string
:   Human-readable name shown in the editor.

`info.description` — string
:   Short description.

`info.dependencies` — array
:   Modules this one requires. Each entry is `{ "name": ..., "version": ... }`. The version is a
    minimum within its minor line, matching `nodos install` semantics. Resolved by the toolchain at
    generation time and by the engine at load time — a module whose hard dependencies cannot be
    satisfied does not load.

`info.category` — string
:   Category used to group the module in the editor.

### Top level

`binary_path` — string
:   Path to the compiled binary, relative to the manifest, without a platform extension. The engine
    appends `.dll`, `.so` or `.dylib`. Omit for modules with no compiled code, such as
    [shader-only node](../how-to/write-a-shader-node.md) plugins.

`sdk_version` — string, required
:   Plugin SDK version this module targets, e.g. `"{{ plugin_sdk_version }}"`. Determines which SDK
    the toolchain fetches and generates a target against. This is what marks a manifest as
    belonging to the {{ nodos_version }} line.

`schema_version` — string
:   Manifest schema version, e.g. `"1.4-v1"`.

`defaults` — array of strings
:   Paths to JSON files providing default pin values for the module's types.

`custom_types` — array of strings
:   Paths to `.fbs` FlatBuffers schemas. The toolchain runs `flatc` over these and generates
    headers into `Include/<PluginName>`. A `Types/` folder is picked up without listing it here.

`third_party_software` — array of strings
:   Paths to JSON files declaring third-party licence information.

## Plugin folder layout

```plaintext
mycorp.myplugin/
├── mycorp.myplugin.nosplugin
├── Binaries/                    # build output; binary_path points here
├── Include/
│   └── mycorpMyplugin/          # public headers, including the plugin's API header
├── Nodes/                       # *.nosnode definitions, auto-discovered
├── Source/                      # C++ implementation; globbed recursively
├── Types/                       # *.fbs schemas
├── Shaders/                     # by convention
├── Tests/                       # graph files run by `nodos test`
├── .nospub                      # optional; limits what `nodos publish` uploads
└── CMakeLists.txt               # optional; additive to the generated target
```

`Source/` is globbed recursively with `CONFIGURE_DEPENDS`, so adding a `.cpp` needs no build file
change.

## See also

- [Node definition](node-definition.md)
- [Workspace layout](workspace-layout.md)
- [Depend on another module](../how-to/depend-on-another-module.md)
