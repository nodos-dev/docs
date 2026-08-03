# Migrate a plugin to Nodos {{ nodos_version }}

Nodos {{ nodos_version }} changed how plugins are described and built. A {{ legacy_version }}
plugin does not load on {{ nodos_version }} unchanged, but the changes are mechanical and the C++
node code mostly survives untouched.

## What changed

| | Nodos {{ legacy_version }} | Nodos {{ nodos_version }} |
|---|---|---|
| Plugin manifest | `*.noscfg` | `*.nosplugin` |
| Subsystem manifest | `*.nossys` | `*.nosplugin` |
| Node definitions | `*.nosdef`, listed in `node_definitions` | `*.nosnode` in `Nodes/`, auto-discovered |
| Schema marker | — | `"schema_version": "1.4-v1"` |
| SDK selection | `nos_find_sdk` in CMake | `"sdk_version"` in the manifest |
| Build files | A `CMakeLists.txt` per plugin, required | Generated from the manifest; optional |
| Project generation | `cmake -S Toolchain/CMake -B Project` | `nodos dev gen` |
| Entry point | Hand-written `ExportNodeFunctions` | `NOS_NODES` list + `PluginMain.inl` |
| Dependency import | `nosEngine.RequestSubsystem` by hand | `NOS_DEPENDENCIES` list |
| Object handles | Raw `nosObjectId` and C structs | `nos::ObjectRef` / `nos::TypedObjectRef` |

## 1. Rename and update the manifest

Rename `MyPlugin.noscfg` to `MyPlugin.nosplugin`, then:

- Add `"sdk_version": "{{ plugin_sdk_version }}"`.
- Add `"schema_version": "1.4-v1"`.
- Delete `node_definitions` — definitions are discovered now.
- Delete `associated_nodes` — menu placement moved into each node definition's `menu_info`.

=== "After ({{ nodos_version }})"

    ```json
    {
        "info": {
            "id": { "name": "mycorp.myplugin", "version": "1.0.0" },
            "display_name": "My Plugin",
            "description": "",
            "dependencies": [
                { "name": "nos.sys.vulkan", "version": "8.0" }
            ],
            "category": "Filters"
        },
        "binary_path": "Binaries/nosMyPlugin",
        "sdk_version": "{{ plugin_sdk_version }}",
        "schema_version": "1.4-v1"
    }
    ```

=== "Before ({{ legacy_version }})"

    ```json
    {
        "info": {
            "id": { "name": "mycorp.myplugin", "version": "1.0.0" },
            "display_name": "My Plugin",
            "description": "",
            "dependencies": [
                { "name": "nos.sys.vulkan", "version": "1.0.0" }
            ]
        },
        "binary_path": "./Binaries/mycorp.myplugin",
        "node_definitions": [ "PrintLog.nosdef" ],
        "defaults": [],
        "custom_types": [],
        "associated_nodes": [
            {
                "category": "Sample",
                "class_name": "PrintLog",
                "display_name": "Print Log"
            }
        ]
    }
    ```

Subsystems use the same `.nosplugin` extension now. There is no longer a separate `.nossys`.

## 2. Convert node definitions

Move each `*.nosdef` into `Nodes/` and rename it to `*.nosnode`. The structure changed: what used
to be a flat node object is now split into `menu_info` (how the editor presents it) and `node` (what
it is).

=== "After ({{ nodos_version }})"

    ```json
    {
      "nodes": [
        {
          "class_name": "PrintLog",
          "menu_info": {
            "category": "Sample",
            "display_name": "Print Log"
          },
          "node": {
            "class_name": "PrintLog",
            "contents_type": "Job",
            "description": "Prints the inputted float into log",
            "pins": [
              {
                "name": "Message",
                "type_name": "float",
                "show_as": "INPUT_PIN",
                "can_show_as": "INPUT_PIN_ONLY"
              }
            ]
          }
        }
      ],
      "schema_version": "1.4-v1"
    }
    ```

=== "Before ({{ legacy_version }})"

    ```json
    {
      "nodes": [
        {
          "class_name": "PrintLog",
          "display_name": "Test to Log",
          "contents_type": "Job",
          "description": "Prints the inputted float into log",
          "pins": [
            {
              "name": "Message",
              "type_name": "float",
              "show_as": "INPUT_PIN",
              "can_show_as": "INPUT_PIN_ONLY"
            }
          ]
        }
      ]
    }
    ```

The `category` and `display_name` that used to live in the manifest's `associated_nodes` entry move
into `menu_info` here. That is the whole reason `associated_nodes` went away — one node, one place
that describes it.

## 3. Delete the CMakeLists (usually)

On {{ nodos_version }} the toolchain generates a target from the manifest. Delete the plugin's
`CMakeLists.txt` if all it did was the standard incantation:

```cmake title="Delete this if it is all you have"
nos_find_sdk("1.3.0" NOS_PLUGIN_SDK_TARGET NOS_SUBSYSTEM_SDK_TARGET NOS_SDK_DIR)
nos_get_module("nos.sys.vulkan" "6.7" NOS_SYS_VULKAN_TARGET)
nos_add_plugin("MyPlugin" "${NOS_PLUGIN_SDK_TARGET};${NOS_SYS_VULKAN_TARGET}" "...")
```

Keep a `CMakeLists.txt` only for genuinely extra build logic — third-party libraries, generated
sources, unusual compile options. It is now *additive*: the toolchain creates the target, sets
`NOS_PLUGIN_TARGET`, then includes your file.

```cmake title="What a CMakeLists.txt looks like now"
target_link_libraries(${NOS_PLUGIN_TARGET} PRIVATE SomeThirdParty)
target_include_directories(${NOS_PLUGIN_TARGET} PRIVATE External/include)
```

Custom FlatBuffers types no longer need `nos_generate_flatbuffers`: put `.fbs` files in `Types/`,
or list paths under `custom_types` in the manifest, and the toolchain runs `flatc` into
`Include/<PluginName>`.

## 4. Rewrite the entry point

Replace the hand-written `ExportNodeFunctions` with the macro list:

=== "After ({{ nodos_version }})"

    ```cpp title="Source/PluginMain.cpp"
    #include <Nodos/Plugin.hpp>
    #include <mycorpMyplugin/mycorpMyplugin.h>
    #include <nosSysVulkan/nosVulkanSubsystem.h>

    #define NOS_NODES         \
        NOS_NODE(PrintLog)    \
        NOS_NODE(Blur)

    #define NOS_DEPENDENCIES     \
        NOS_DEPENDENCY(NOS_VULKAN)

    #define NOS_NAMESPACE mycorp::myplugin

    #include <Nodos/PluginMain.inl>
    ```

=== "Before ({{ legacy_version }})"

    ```cpp
    NOS_INIT()
    NOS_BEGIN_IMPORT_DEPS()
    NOS_END_IMPORT_DEPS()

    struct PluginExtension : public nos::PluginFunctions
    {
        virtual nosResult ExportNodeFunctions(size_t& outSize,
                                              nosNodeFunctions** outFunctions) override
        {
            outSize = 2;
            if (!outFunctions)
                return NOS_RESULT_SUCCESS;
            NOS_RETURN_ON_FAILURE(RegisterPrintLog(outFunctions[0]));
            NOS_RETURN_ON_FAILURE(RegisterBlur(outFunctions[1]));
            return NOS_RESULT_SUCCESS;
        }
    };

    NOS_EXPORT_PLUGIN_FUNCTIONS(PluginExtension);
    ```

Each `NOS_NODE(X)` requires a matching `nosResult RegisterX(nosNodeFunctions*)` in the
`NOS_NAMESPACE` namespace. Your existing registration functions already have that shape, so this
step is usually just deleting code.

If you need to override other plugin-level callbacks, define `NOS_PLUGIN_FUNCTIONS_NAME` before
including `PluginMain.inl` and declare your own struct deriving from `nos::PluginFunctions`.

## 5. Move to object references

Where you held raw `nosObjectId` values or C resource structs, switch to `nos::ObjectRef` and
`nos::TypedObjectRef`. They are RAII wrappers over the engine's reference counting, and they remove
a class of leak that was easy to hit by hand. See
[Objects and the type system](../explanation/objects-and-types.md).

## 6. Rebuild

```shell
nodos dev gen --clean
nodos dev build
```

`--clean` deletes the CMake output directory first, which you want here because the target
generation strategy has changed entirely.

## 7. Bump your version

Changing the manifest schema is not itself an API break for your consumers, but if this migration
changed your plugin's public API — headers, exported struct layout, node pin contracts — bump the
major version in `info.id.version`. See
[Versioning and SDK lines](../explanation/versioning.md).

## Checklist

- [ ] `.noscfg` / `.nossys` renamed to `.nosplugin`
- [ ] `sdk_version` and `schema_version` added
- [ ] `node_definitions` and `associated_nodes` removed
- [ ] `.nosdef` files moved to `Nodes/` as `.nosnode`, restructured into `menu_info` + `node`
- [ ] Menu category and display name moved into `menu_info`
- [ ] Boilerplate `CMakeLists.txt` deleted, or reduced to additive lines only
- [ ] Entry point replaced with `NOS_NODES` / `NOS_DEPENDENCIES` / `PluginMain.inl`
- [ ] Raw object handles replaced with `nos::ObjectRef`
- [ ] `nodos dev gen --clean && nodos dev build` succeeds
- [ ] Plugin loads and every node appears in the editor
