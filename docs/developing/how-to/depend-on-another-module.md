# Depend on another module

Plugins and subsystems expose C APIs to each other. Using one takes three steps: declare the
dependency in the manifest, import its API in C++, and check that the import succeeded.

## 1. Declare the dependency

Add it to your manifest's `info.dependencies`:

```json title="mycorp.myplugin.nosplugin" hl_lines="8-13"
{
    "info": {
        "id": {
            "name": "mycorp.myplugin",
            "version": "0.1.0"
        },
        "display_name": "My Plugin",
        "dependencies": [
            {
                "name": "nos.sys.vulkan",
                "version": "8.0"
            }
        ]
    },
    "binary_path": "Binaries/nosMyPlugin",
    "sdk_version": "{{ plugin_sdk_version }}"
}
```

Or let the CLI write it:

```shell
nodos depend mycorp.myplugin nos.sys.vulkan-8.0
```

The version is a minimum within a minor line, matching
[`nodos install`](../../using/how-to/manage-packages.md#install-a-package) semantics. The toolchain resolves and
fetches it during `nodos dev gen`, and the engine resolves it again at load time — a plugin whose
hard dependencies cannot be satisfied does not load.

## 2. Import the API

!!! info "Nodos {{ nodos_version }}"

    Dependencies go in the `NOS_DEPENDENCIES` list in `PluginMain.cpp`. Each entry is the
    dependency's `*_NAME`-style macro, defined in its public header:

    ```cpp title="Source/PluginMain.cpp" hl_lines="3 9-10"
    #include <Nodos/Plugin.hpp>
    #include <mycorpMyplugin/mycorpMyplugin.h>
    #include <nosSysVulkan/nosVulkanSubsystem.h>

    #define NOS_NODES        \
        NOS_NODE(Blur)

    #define NOS_DEPENDENCIES     \
        NOS_DEPENDENCY(NOS_VULKAN)

    #define NOS_NAMESPACE mycorp::myplugin

    #include <Nodos/PluginMain.inl>
    ```

    `PluginMain.inl` expands each entry twice: once into `NOS_VULKAN_INIT()`, which defines the
    global API pointer, and once into `NOS_VULKAN_IMPORT()` inside `nosImportDependencies`. After
    that the dependency's global — `nosVulkan` here — is usable from any translation unit that
    includes its header.

    The token you pass to `NOS_DEPENDENCY` is the prefix of that pair, so check the dependency's
    public header for its `*_INIT()` / `*_IMPORT()` macros. For `nos.sys.vulkan` they are
    `NOS_VULKAN_INIT()` and `NOS_VULKAN_IMPORT()`, hence `NOS_DEPENDENCY(NOS_VULKAN)`.

    ??? note "Doing it without `PluginMain.inl`"
        Plugins that predate the macro list, or that need finer control, write the same thing out
        by hand:

        ```cpp
        NOS_INIT()
        NOS_VULKAN_INIT()

        NOS_BEGIN_IMPORT_DEPS()
            NOS_VULKAN_IMPORT()
        NOS_END_IMPORT_DEPS()
        ```

        This is what several of the shipped plugins still do; both forms are supported.

??? warning "Nodos {{ legacy_version }} and earlier"

    There is no `NOS_DEPENDENCIES` list, and the include folder is `nosVulkanSubsystem/` rather
    than `nosSysVulkan/`. Request the subsystem by hand inside `nosExportNodeFunctions`, and check
    the result:

    ```cpp
    #include <nosVulkanSubsystem/nosVulkanSubsystem.h>

    nosVulkanSubsystem* nosVulkan = nullptr;

    auto ret = nosEngine.RequestSubsystem(
        NOS_NAME_STATIC(NOS_VULKAN_SUBSYSTEM_NAME), 1, 0, (void**)&nosVulkan);
    if (ret != NOS_RESULT_SUCCESS)
        return ret;
    ```

    The manifest is a `.noscfg` (plugins) or `.nossys` (subsystems) rather than `.nosplugin`, but
    the `dependencies` array is the same shape.

## 3. Check availability

A declared dependency is resolved before your plugin loads, so by the time your nodes run the API
pointer is valid. But when you request a subsystem manually — the {{ legacy_version }} path above,
or any optional dependency — the request can fail because the requested version is not installed.

Always check:

```cpp
if (ret != NOS_RESULT_SUCCESS)
{
    nosEngine.LogE("nos.sys.vulkan is not available at the required version");
    return ret;
}
```

Failing loudly here is much better than a null dereference three frames into execution.

## Sharing dependencies across several plugins

When several plugins live under one directory tree and share dependencies, add a
`NosPluginCommon.cmake` to the common parent directory and define:

```cmake
function(nos_plugin_common dir out_deps out_defs)
    set(${out_deps} SomeSharedTarget PARENT_SCOPE)
    set(${out_defs} MY_SHARED_DEFINE=1 PARENT_SCOPE)
endfunction()
```

The toolchain calls it once per directory while scanning and applies the results to every plugin
found beneath it. `out_deps` are extra CMake targets to link; `out_defs` are preprocessor
definitions.

You can also define `nos_plugin_on_post_target_generated(target name)` in the same file to run
logic after each target is created.

## Extending a generated target

If one plugin needs extra sources, include paths or link libraries, add a `CMakeLists.txt` next to
its `.nosplugin`. The toolchain sets `NOS_PLUGIN_TARGET` and includes your file after creating the
target:

```cmake
target_include_directories(${NOS_PLUGIN_TARGET} PRIVATE External/include)
target_link_libraries(${NOS_PLUGIN_TARGET} PRIVATE SomeThirdParty)
```

This is additive. You are extending a target the toolchain already made, not defining your own.

## Exposing your own API

To let other modules depend on *you*, fill in the API struct in your public header — the scaffolded
`Include/<CamelCase>/<CamelCase>.h` — and populate it from the `OnRequestAPI` callback in your
plugin functions. The `*_NAME`, `*_INIT()` and `*_IMPORT()` macros that consumers need are already
in that header; the scaffold generates them.
