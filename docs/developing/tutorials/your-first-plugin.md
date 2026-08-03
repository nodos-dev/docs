# Your first plugin

In this tutorial you will create a plugin, define a node in it, implement that node in C++, build
it, and load it into a running editor. At the end, a node you wrote will appear in the right-click
menu alongside the built-in ones.

Budget about 30 minutes.

!!! note "What you need"
    - [Your first graph](../../using/tutorials/your-first-graph.md) completed, so you have a workspace with an engine in
      it.
    - CMake 3.24.2 or newer.
    - A {{ cpp_version }}-capable compiler — MSVC on Windows, GCC or Clang elsewhere.

## Step 1: Scaffold the plugin

From your workspace root:

```shell
nodos create mycorp.myplugin --description "My first Nodos plugin"
```

Plugin names are dotted and namespaced — `mycorp.myplugin` — because they become globally unique
package identifiers on the Nodos Store. Pick a namespace you control.

This creates:

```plaintext
Module/mycorp.myplugin/
├── mycorp.myplugin.nosplugin      # manifest: identity, dependencies, SDK version
├── Include/
│   └── mycorpMyplugin/
│       └── mycorpMyplugin.h       # your plugin's public API header
├── Nodes/                         # .nosnode node definitions go here
├── Source/
│   └── PluginMain.cpp             # entry point and node registration
└── Types/                         # .fbs custom type schemas go here
```

Note what is *not* there: no `CMakeLists.txt`. On Nodos {{ nodos_version }} the toolchain generates
a CMake target from the manifest. You only add a `CMakeLists.txt` if you need extra sources or
build logic — see [Workspace layout](../reference/workspace-layout.md).

The manifest is small:

```json title="mycorp.myplugin.nosplugin"
{
    "info": {
        "id": {
            "name": "mycorp.myplugin",
            "version": "0.1.0"
        },
        "display_name": "mycorp.myplugin",
        "description": "My first Nodos plugin",
        "dependencies": []
    },
    "sdk_version": "{{ plugin_sdk_version }}"
}
```

`sdk_version` is what makes this a Nodos {{ nodos_version }} plugin. The toolchain reads it,
fetches that SDK if needed, and generates the build target against it.

## Step 2: Declare a node

A node has two halves: a **definition** that describes its pins and how it appears in the editor,
and an **implementation** in C++. The definition comes first, because the engine refuses to
register an implementation for a node class it has never heard of.

Create the definition with the CLI:

```shell
nodos node mycorp.myplugin PrintFloat \
  --display-name "Print Float" \
  --description "Prints a float to the log" \
  --category "Tutorial"
```

That writes `Nodes/PrintFloat.nosnode` with no pins yet.

Open the file and add a `Message` pin:

```json title="Nodes/PrintFloat.nosnode" hl_lines="12-19"
{
  "nodes": [
    {
      "class_name": "mycorp.myplugin.PrintFloat",
      "menu_info": {
        "category": "Tutorial",
        "display_name": "Print Float",
        "hide_in_context_menu": false
      },
      "node": {
        "contents_type": "Job",
        "description": "Prints a float to the log",
        "display_name": "Print Float",
        "pins": [
          {
            "name": "Message",
            "type_name": "float",
            "show_as": "INPUT_PIN",
            "can_show_as": "INPUT_PIN_OR_PROPERTY"
          }
        ]
      }
    }
  ]
}
```

`show_as` is how the pin appears by default; `can_show_as` is what the user is allowed to change it
to. Declaring `INPUT_PIN_OR_PROPERTY` means someone can collapse this pin into a property they type
a value into, instead of wiring it. The full set of options is in
[Node definition](../reference/node-definition.md).

!!! tip "`nodos pin` does the same job"
    Pins can also be added from the CLI, which is quicker once you know the flags:

    ```shell
    nodos pin mycorp.myplugin.PrintFloat Message \
      --type-name float --show-as INPUT_PIN --can-show-as INPUT_PIN_OR_PROPERTY
    ```

    See [Add nodes and pins](../how-to/add-nodes-and-pins.md).

!!! info "Nodes are discovered automatically"
    Every `.nosnode` under `Nodes/` is picked up. You do not list them in the manifest.

## Step 3: Implement the node

Create `Source/PrintFloat.cpp`:

```cpp title="Source/PrintFloat.cpp"
#include <Nodos/Plugin.hpp>

#include <string>

namespace mycorp::myplugin
{

struct PrintFloat : nos::NodeContext
{
    using nos::NodeContext::NodeContext;

    nosResult ExecuteNode(nos::NodeExecuteParams const& params) override
    {
        float value = *params.GetPinValue<float>(NOS_NAME("Message"));
        nosEngine.LogI("PrintFloat: %f", value);
        SetNodeStatusMessage(std::to_string(value), nos::fb::NodeStatusMessageType::INFO);
        return NOS_RESULT_SUCCESS;
    }
};

nosResult RegisterPrintFloat(nosNodeFunctions* outFunctions)
{
    NOS_BIND_NODE_CLASS(NOS_NAME("mycorp.myplugin.PrintFloat"), PrintFloat, outFunctions)
    return NOS_RESULT_SUCCESS;
}

}
```

Three things are load-bearing here:

`ExecuteNode` is called when the node runs as part of a scheduled path. It is not called because a
value changed — it is called because the scheduler decided this node is due. If you want to react
to a value changing outside execution, override `OnPinValueChanged` instead.

`NOS_BIND_NODE_CLASS` wires your struct to a node class name. The name must exactly match the
`class_name` in the `.nosnode` file, fully qualified.

`RegisterPrintFloat` follows a naming convention: for a node called `PrintFloat`, the registration
function must be `RegisterPrintFloat`. The next step relies on that.

## Step 4: Register the node with the plugin

Open `Source/PluginMain.cpp` and add your node to the `NOS_NODES` list:

```cpp title="Source/PluginMain.cpp" hl_lines="5-6"
// This header includes the PluginAPI.h and helpers from Nodos SDK
#include <Nodos/Plugin.hpp>
#include <mycorpMyplugin/mycorpMyplugin.h>

#define NOS_NODES \
    NOS_NODE(PrintFloat)

// Add dependencies to NOS_DEPENDENCIES macro
#define NOS_DEPENDENCIES

// This will be the namespace of your plugin
#define NOS_NAMESPACE mycorp::myplugin

// This includes the entry point implementation, dependency initialization, and node registration code.
#include <Nodos/PluginMain.inl>
```

`PluginMain.inl` expands that list into the plugin entry point: it declares
`nosResult RegisterPrintFloat(nosNodeFunctions*)` for you, builds the node enum, and generates the
`ExportNodeFunctions` implementation that the engine calls twice — once to ask how many nodes there
are, once to collect them.

That is why the registration function name matters. Adding a node is now a two-line change: one
`NOS_NODE(...)` entry and one `Register...` function.

## Step 5: Build

Generate project files and build:

```shell
nodos dev gen
nodos dev build
```

`nodos dev gen` scans `Module/` for manifests and generates a CMake project into `Project/`.
`nodos dev build` drives the build. Output lands in `Module/mycorp.myplugin/Binaries/`.

If you would rather work in an IDE, `nodos dev gen` has already produced a normal CMake project in
`Project/` that you can open directly.

??? note "Building a plugin that lives outside the workspace"
    ```shell
    nodos dev gen --plugin-dirs "/path/to/my/repo"
    nodos dev build
    ```

## Step 6: Load it

Launch Nodos:

```shell
nodos launch
```

In the editor, open the **Modules** pane and click **Fetch**. Your plugin appears in the
uncategorised table. Select it and click **Load**.

Now right-click the node graph and search for **Print Float**. Place it, wire an **Add** node into
its `Message` pin, and attach the whole thing to a Thread and a Sink as you did in
[Your first graph](../../using/tutorials/your-first-graph.md).

The node's status shows the value, and the **Log** pane shows a line per frame.

## What you built

```plaintext
.nosnode  ──▶ engine knows the node class exists, and its pins
   +
C++ struct ─▶ engine knows what to run
   +
NOS_NODES ──▶ plugin exports the registration to the engine
```

All three must agree on the class name. When a node does not show up, a mismatch between these is
almost always the reason.

## Next

- [Add nodes and pins](../how-to/add-nodes-and-pins.md) — add the second, third and fourth node.
- [Plugin API (C++)](../reference/plugin-api.md) — the rest of the `NodeContext` callbacks.
- [Write a shader-only node](../how-to/write-a-shader-node.md) — a GPU node with no C++ at all.
- [Publish a package](../how-to/publish-a-package.md) — when you want other people to install it.
