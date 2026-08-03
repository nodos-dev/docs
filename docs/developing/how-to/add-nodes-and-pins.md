# Add nodes and pins

This guide covers adding a node to an existing plugin, and adding pins to an existing node. If you
have not created a plugin yet, start with
[Your first plugin](../tutorials/your-first-plugin.md).

## Add a node

### 1. Create the definition

```shell
nodos node mycorp.myplugin Blur -n {{ nodos_version }} \
  --display-name "Blur" \
  --description "Gaussian blur" \
  --category "Filters"
```

This writes `Nodes/Blur.nosnode` inside the plugin, with an empty `pins` array.

!!! danger "Always pass `-n {{ nodos_version }}`"
    Without it, `nodos node` cannot see existing `Nodes/*.nosnode` definitions — see
    [the known issue below](#known-issue-node-definition-discovery). Re-running the command for a
    class that already exists then **overwrites its definition and silently discards every pin on
    it**, with no error. `--remove` fails outright with `Node class ... not found`.

    Passing `-n {{ nodos_version }}` makes both behave correctly.

Useful flags:

`-n, --nodos-version`
:   Which Nodos line to target. Determines whether `Nodes/*.nosnode` files are discovered
    (Nodos {{ nodos_version }}+) or the manifest's `node_definitions` array is used
    ({{ legacy_version }}). Pass it explicitly — the fallback is unreliable.

`--hide`
:   Sets `hide_in_context_menu`. Use for nodes that only make sense when created programmatically
    or as a preset.

`--remove`
:   Deletes the node class. If it was the only node in its file, the file is removed too.

### 2. Add pins

Edit the generated `.nosnode` directly:

```json hl_lines="6-19"
{
  "nodes": [
    {
      "class_name": "mycorp.myplugin.Blur",
      "menu_info": { "category": "Filters", "display_name": "Blur" },
      "node": {
        "contents_type": "Job",
        "pins": [
          {
            "name": "Input",
            "type_name": "nos.sys.vulkan.Texture",
            "show_as": "INPUT_PIN",
            "can_show_as": "INPUT_PIN_ONLY"
          },
          {
            "name": "Radius",
            "type_name": "float",
            "show_as": "PROPERTY",
            "can_show_as": "INPUT_PIN_OR_PROPERTY",
            "data": 4.0,
            "min": 0.0,
            "max": 64.0
          },
          {
            "name": "Output",
            "type_name": "nos.sys.vulkan.Texture",
            "show_as": "OUTPUT_PIN",
            "can_show_as": "OUTPUT_PIN_ONLY"
          }
        ]
      }
    }
  ],
  "schema_version": "1.4-v1"
}
```

Every field is documented in [Node definition](../reference/node-definition.md). The two that
people get wrong:

**`show_as` vs `can_show_as`.** `show_as` is the initial presentation. `can_show_as` is the set of
presentations the user may switch to. A pin that is `PROPERTY` / `INPUT_PIN_OR_PROPERTY` starts as
an editable field and can be promoted to a wired input.

**`data`.** The default value, in the pin's own type. Include it for properties — a property with
no default shows as zero or empty, which is rarely what you want.

Editing the file by hand is currently the only way to add a pin on Nodos {{ nodos_version }} — the
`nodos pin` command cannot find {{ nodos_version }} node definitions at all.

## Known issue: node definition discovery

Verified against nosman 0.17.

The commands that *look up* an existing node class only scan `Nodes/*.nosnode` when they know they
are targeting Nodos {{ nodos_version }} or newer. They learn that from the `-n/--nodos-version`
argument — and nothing else. When it is absent they fall back to {{ legacy_version }} behaviour and
read only the manifest's `node_definitions` array, which a {{ nodos_version }} plugin does not have.

| Command | Without `-n {{ nodos_version }}` | With `-n {{ nodos_version }}` |
|---|---|---|
| `nodos node <plugin> <Class>` | Overwrites an existing definition, **silently discarding its pins** | Correct — reports that the class already exists |
| `nodos node <plugin> <Class> --remove` | `Error: Node class ... not found` | Works |
| `nodos pin <Class> <Pin>` | `Error: Node class ... not found` | **Not available** — `nodos pin` does not accept `-n` |

So:

- **For `nodos node`, always pass `-n {{ nodos_version }}`.** The data-loss case above is silent, and
  re-running a scaffolding command is an easy thing to do.
- **For `nodos pin`, there is no workaround.** It never registers the argument, so it cannot be told
  which line to target. Edit the `.nosnode` JSON directly, as above.

??? note "On Nodos {{ legacy_version }}, `nodos pin` works normally"
    Definitions *are* listed in the manifest on that line, which is exactly what the command reads:

    ```shell
    nodos pin mycorp.myplugin.Blur Radius \
      --show-as PROPERTY --can-show-as INPUT_PIN_OR_PROPERTY --type-name float
    ```

    Omitting any of `--show-as`, `--can-show-as` or `--type-name` drops it into an interactive
    prompt. `--remove` deletes the pin.

    Adding a `node_definitions` array to a {{ nodos_version }} manifest does make `nodos pin` find
    the node — but it is not a fix worth applying. On {{ nodos_version }} the same file would then
    be picked up twice, once by folder scan and once by the manifest entry.

### 3. Implement it

Add a source file with a context struct and a registration function named `Register<NodeName>`:

```cpp title="Source/Blur.cpp"
#include <Nodos/Plugin.hpp>

namespace mycorp::myplugin
{

struct Blur : nos::NodeContext
{
    using nos::NodeContext::NodeContext;

    nosResult ExecuteNode(nos::NodeExecuteParams const& params) override
    {
        float radius = *params.GetPinValue<float>(NOS_NAME("Radius"));
        // ...
        return NOS_RESULT_SUCCESS;
    }
};

nosResult RegisterBlur(nosNodeFunctions* outFunctions)
{
    NOS_BIND_NODE_CLASS(NOS_NAME("mycorp.myplugin.Blur"), Blur, outFunctions)
    return NOS_RESULT_SUCCESS;
}

}
```

### 4. Register it

Add one line to `Source/PluginMain.cpp`:

```cpp hl_lines="3"
#define NOS_NODES         \
    NOS_NODE(PrintFloat)  \
    NOS_NODE(Blur)
```

The name in `NOS_NODE(...)` must match the `Register...` function suffix. `PluginMain.inl`
generates the declaration and the dispatch from this list.

You do not need to touch CMake. `nodos dev gen` globs `Source/` recursively with
`CONFIGURE_DEPENDS`, so a new `.cpp` is picked up automatically.

### 5. Rebuild

```shell
nodos dev build
```

## Choose when your node executes

By default a node executes when one of its inputs is dirty. That is right for pure
transformations, and wrong for anything that produces something new each frame.

Set `always_execute` in the node definition when the node must run even with unchanged inputs:

```json
"node": {
  "contents_type": "Job",
  "always_execute": true,
  "pins": [ ... ]
}
```

Use it for:

- time-varying sources (a signal generator, a clock),
- per-frame side effects or edge detection,
- threaded sources that push data in from outside the graph,
- nodes whose callable functions mutate internal state without writing to a pin.

Leave it off otherwise. Calling `SetPinValue` on an input pin — from a node function, say — dirties
the node and re-triggers `ExecuteNode` on its own, so you rarely need `always_execute` just to make
a button work.

## Add a callable function to a node

Functions are the buttons that appear on a node — `LoadModel`, `Reset`, and so on. Declare them in
the definition's `functions` array, then list them with `NOS_DECLARE_FUNCTIONS` on the context
struct. See [Node definition](../reference/node-definition.md#node) and
[Plugin API](../reference/plugin-api.md#node-functions).

## Verify

Reload the plugin from the editor's **Modules** pane, then right-click the graph and search for
your node. If it does not appear, work through
[the checklist in Get help](../../about/get-help.md#a-node-does-not-appear-in-the-right-click-menu).
