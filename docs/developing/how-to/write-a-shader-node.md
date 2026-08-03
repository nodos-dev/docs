# Write a shader-only node

A shader-only node runs a GPU pass and has no C++ behind it at all — no source file, no compiled
binary, no exported node functions. You write a node definition, point it at a shader, and
`nos.sys.vulkan` does the rest.

This is how nodes like *Color Correct* are built, and it is the right choice for any node that is
purely a fragment or compute pass over its inputs.

## 1. Declare the dependency

The plugin needs `nos.sys.vulkan`, because that subsystem owns shader compilation:

```json title="mycorp.myplugin.nosplugin"
{
    "info": {
        "id": { "name": "mycorp.myplugin", "version": "0.1.0" },
        "display_name": "My Plugin",
        "dependencies": [
            { "name": "nos.sys.vulkan", "version": "8.0" }
        ]
    },
    "sdk_version": "{{ plugin_sdk_version }}",
    "schema_version": "1.4-v1"
}
```

Note there is no `binary_path`. A plugin containing only shader nodes ships no library.

## 2. Write the shader

Put it anywhere in the plugin; `Shaders/` is conventional.

```hlsl title="Shaders/ColorCorrect.hlsl"
Texture2D Input : register(t0);
SamplerState Sampler : register(s0);

cbuffer Params : register(b0)
{
    float Gain;
};

float4 main(float2 uv : TEXCOORD0) : SV_TARGET
{
    return Input.Sample(Sampler, uv) * Gain;
}
```

HLSL and GLSL both work. `nos.sys.vulkan` tries `glslc` and `dxc` and uses whichever compiles.
If the file extension is `.spv` it is taken as a precompiled SPIR-V blob and used as-is.

## 3. Define the node

The `contents` field is what makes this a GPU node rather than a job the engine expects C++ for.

```json title="Nodes/ColorCorrect.nosnode"
{
  "nodes": [
    {
      "class_name": "ColorCorrect",
      "menu_info": {
        "category": "Filters",
        "display_name": "Color Correct"
      },
      "node": {
        "class_name": "ColorCorrect",
        "contents_type": "Job",
        "contents": {
          "type": "nos.sys.vulkan.GPUNode",
          "options": {
            "shader": "../Shaders/ColorCorrect.hlsl",
            "stage": "FRAGMENT"
          }
        },
        "pins": [
          {
            "name": "Input",
            "type_name": "nos.sys.vulkan.Texture",
            "show_as": "INPUT_PIN",
            "can_show_as": "INPUT_PIN_ONLY"
          },
          {
            "name": "Gain",
            "type_name": "float",
            "show_as": "PROPERTY",
            "can_show_as": "INPUT_PIN_OR_PROPERTY",
            "data": 1.0
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

Two details that matter:

**The `shader` path is relative to the manifest**, not to the node definition file. In the layout
above, `Nodes/ColorCorrect.nosnode` and the manifest sit in the plugin root, so `../Shaders/...`
resolves from there.

**Pins bind to shader parameters by name.** The `Gain` pin above feeds the `Gain` constant buffer
member. This is the whole point of shader-only nodes — you do not write binding code, you match
names.

Set `"stage": "COMPUTE"` for a compute shader instead. A render pass needs a fragment shader; the
vertex shader is optional, and a full-quad vertex shader is supplied when you omit it.

## 4. Build and load

There is no C++ to compile, but the plugin still has to be registered with the workspace:

```shell
nodos dev gen
```

Then load it from the editor's **Modules** pane. The node appears under *Filters*.

## Iterating on the shader

Shaders can be recompiled without restarting the engine. The `nos.sys.vulkan` API exposes
`ReloadShaders(nosName nodeName)` for this; the editor surfaces it on GPU nodes.

## When you need C++ after all

Shader-only nodes cannot hold state between frames, allocate their own resources, or decide at
runtime which pass to run. When you need any of that, write a normal node and record GPU commands
yourself — see [Use the Vulkan subsystem](use-the-vulkan-subsystem.md).

The two approaches coexist in one plugin. Shader-only nodes just skip the parts they do not need.
