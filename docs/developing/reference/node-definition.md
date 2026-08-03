# Node definition

A node definition describes a node class: its pins, how the editor presents it, and — for GPU nodes
— what it runs. One file may define several node classes.

Definitions live in `Nodes/*.nosnode` and are discovered automatically. Do not list them in the
manifest.

## Structure

```json
{
  "nodes": [
    {
      "class_name": "PrintFloat",
      "menu_info": { "...": "how the editor presents it" },
      "node":      { "...": "what it is" }
    }
  ],
  "schema_version": "1.4-v1"
}
```

The split is deliberate: `menu_info` is editor presentation, `node` is the class itself.

## Complete example

```json title="Nodes/LLMGenerate.nosnode"
{
	"nodes": [
		{
			"class_name": "LLMGenerate",
			"menu_info": {
				"category": "AI",
				"display_name": "LLM Generate"
			},
			"node": {
				"class_name": "LLMGenerate",
				"contents_type": "Job",
				"description": "Loads a GGUF model and generates a completion for the given prompt.",
				"pins": [
					{
						"name": "ModelPath",
						"type_name": "string",
						"show_as": "PROPERTY",
						"can_show_as": "INPUT_PIN_OR_PROPERTY",
						"visualizers": [
							{
								"type": "FILE_PICKER",
								"file_extensions": ["gguf"],
								"file_picker_type": "OPEN"
							}
						]
					},
					{
						"name": "Temperature",
						"type_name": "float",
						"show_as": "PROPERTY",
						"can_show_as": "INPUT_PIN_OR_PROPERTY",
						"data": 0.7
					},
					{
						"name": "Output",
						"type_name": "string",
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

## Node entry

`class_name` — string, required
:   The node class name. If it is not already prefixed with the owning module's name, the module
    name is prepended when the definition is loaded, so `LLMGenerate` in `nos.llm` becomes
    `nos.llm.LLMGenerate`.

    This is the name that must match `NOS_BIND_NODE_CLASS`, fully qualified.

`menu_info` — object
:   Editor presentation. See below.

`node` — object, required
:   The node class itself. See below.

`presets` — array
:   Preconfigured variants of the same class, each with its own `menu_info` and a `params` list
    setting pin values. This is how one generic `Arithmetic` class provides *Add*, *Sub*, *Mul*,
    *Div* and *Log* menu entries.

`hide_in_context_menu` — bool
:   Hide from the right-click menu. Useful on a base class that only ships presets.

## `menu_info`

`category` — string
:   Menu category. Nest with `|`, e.g. `"Math|Addition"`.

`display_name` — string
:   Name shown in the editor.

`name_aliases` — array of strings
:   Extra search terms. `Add` carries `["plus", "sum"]` so that searching either finds it. Worth
    filling in — it is the cheapest usability improvement available to a node author.

`hide_in_context_menu` — bool
:   Hide from the right-click menu.

## `node`

`contents_type` — string, required
:   `"Job"` for a node that does work, `"Graph"` for one containing a subgraph.

`class_name` — string
:   Class name, repeated. Conventionally present.

`display_name` — string
:   Overrides the display name for this class.

`description` — string
:   Description shown in the editor.

`always_execute` — bool, default `false`
:   Execute every frame even when no input is dirty.

    Leave it `false` for pure transformations. Set it `true` for time-varying sources, per-frame
    side effects or edge detection, threaded sources, and functions that mutate internal state
    without writing to a pin. Note that `SetPinValue` on an input pin dirties the node on its own,
    so a callable function usually does not need this.

`pins` — array
:   Pin definitions. See below.

`functions` — array
:   Callable functions — the buttons on a node. Each entry is shaped like a node: `class_name`,
    `contents_type`, optional `contents` and `pins`. Bind them from a static `GetFunctions` on the
    context struct; see [Plugin API](plugin-api.md#node-functions).

`contents` — object
:   What the node runs, for nodes not implemented in your plugin's C++.

    ```json
    "contents": {
      "type": "nos.sys.vulkan.GPUNode",
      "options": {
        "shader": "../Shaders/ColorCorrect.hlsl",
        "stage": "FRAGMENT"
      }
    }
    ```

    `type` is `nos.sys.vulkan.GPUNode` for a shader node or `nos.py.PythonNode` for a Python node.
    The `shader` path is relative to the **manifest**, not to this file. `stage` is `FRAGMENT` or
    `COMPUTE`. If the file extension is not `.spv`, `nos.sys.vulkan` compiles it with whichever of
    `glslc` and `dxc` succeeds. See
    [Write a shader-only node](../how-to/write-a-shader-node.md).

`template_parameters` — array
:   Parameters for generic node classes.

`status_messages` — array
:   Predeclared status messages.

`meta_data_map` — object
:   Free-form key/value metadata.

## Pins

### Required

`name` — string
:   Pin name. This is the identity used by `GetPinValue(NOS_NAME("..."))` and, for shader nodes, the
    shader parameter it binds to.

`type_name` — string
:   Data type. A built-in such as `float`, `string`, `uint`, `bool`; a module type such as
    `nos.sys.vulkan.Texture` or `nos.audio.AudioPacket`; `nos.exe` for an execution pin; or
    `nos.Generic` for a pin whose type resolves on connection. See
    [Built-in data types](builtin-types.md).

`show_as` — string
:   Initial presentation: `INPUT_PIN`, `OUTPUT_PIN` or `PROPERTY`.

### Presentation

`can_show_as` — string
:   What the user may switch it to. One of `PROPERTY_ONLY`, `INPUT_PIN_ONLY`,
    `INPUT_PIN_OR_PROPERTY`, `OUTPUT_PIN_OR_PROPERTY`, `OUTPUT_PIN_ONLY`, `INPUT_OUTPUT`,
    `INPUT_OUTPUT_PROPERTY`.

`display_name` — string
:   Label shown in the editor when it should differ from `name`. Use this rather than putting
    spaces in `name`.

`description` — string
:   Tooltip text.

`pin_category` — string
:   Groups pins into sections on the node.

`advanced_property` — bool
:   Hide behind the advanced disclosure.

`readonly` — bool
:   Display only; not user-editable.

### Values

`data` — any
:   Current default value, in the pin's own type.

`def` — any
:   The value "reset to default" restores.

`min`, `max` — number
:   Range limits for numeric pins. Enforced by the editor widget.

`step` — number
:   Increment for drag and spin widgets.

### Behaviour

`live` — bool
:   Marks the pin as live.

`connection_conditions` — string
:   Constrains what may connect. For example `"!resource"` on the generic `Arithmetic` pins rejects
    resource types, so an Add node cannot be handed a texture.

`visualizers` — array
:   Editor widgets for the pin.

    | `type` | Purpose | Extra fields |
    |---|---|---|
    | `FILE_PICKER` | File chooser | `file_extensions`, `file_picker_type` (`OPEN` / `SAVE`) |
    | `FOLDER_PICKER` | Directory chooser | |
    | `COLOR_PICKER` | Colour swatch | |
    | `COMBO_BOX` | Dropdown | `name` of the value set |
    | `NAMED_VALUE` | Named value from a registered set | `name` |

`meta_data_map` — object
:   Free-form key/value metadata.

## Execution pins

Pins of type `nos.exe` carry no data. They express ordering: that one node runs after another. A
node's execution input is conventionally `InExe` or `Run`, and its output `Continue` or `Out`.

Execution pins are what connect a node to a thread and a sink, and therefore what makes it run at
all. See [Scheduling and execution](../../using/explanation/scheduling.md).

## See also

- [Plugin manifest](plugin-manifest.md)
- [Add nodes and pins](../how-to/add-nodes-and-pins.md)
- [Built-in data types](builtin-types.md)
