# Use the Vulkan subsystem

`nos.sys.vulkan` gives plugins access to GPU resources and command recording. This guide covers
getting the API pointer and recording work; the full call surface is in the
[`nos.sys.vulkan` reference](../reference/subsystems/nos.sys.vulkan.md).

Prefer the C++ helpers in `<nosSysVulkan/Helpers.hpp>` over the raw C function pointers. They
handle the parameter structs and return RAII object references, and they are what the shipped
plugins use.

## 1. Declare and import

Add the dependency to your manifest:

```json title="mycorp.myplugin.nosplugin"
"dependencies": [
    { "name": "nos.sys.vulkan", "version": "8.0" }
]
```

Then import it in `PluginMain.cpp`:

```cpp title="Source/PluginMain.cpp" hl_lines="3 8-9"
#include <Nodos/Plugin.hpp>
#include <mycorpMyplugin/mycorpMyplugin.h>
#include <nosSysVulkan/nosVulkanSubsystem.h>

#define NOS_NODES     \
    NOS_NODE(Fill)

#define NOS_DEPENDENCIES     \
    NOS_DEPENDENCY(NOS_VULKAN)

#define NOS_NAMESPACE mycorp::myplugin

#include <Nodos/PluginMain.inl>
```

The global `nosVulkan` is now available anywhere you include the header.

??? warning "Nodos {{ legacy_version }}"
    The include path is `<nosVulkanSubsystem/nosVulkanSubsystem.h>`, you request the subsystem
    manually with `nosEngine.RequestSubsystem` and check the result, and the API itself differs —
    resources are passed as `nosResourceShareInfo*` rather than object handles. See
    [Depend on another module](depend-on-another-module.md).

## 2. Record commands

Every GPU operation goes through a `nosCmd`: begin, record, end.

```cpp title="Source/Fill.cpp"
#include <Nodos/Plugin.hpp>
#include <nosSysVulkan/nosVulkanSubsystem.h>
#include <nosSysVulkan/Helpers.hpp>

namespace mycorp::myplugin
{
namespace vkss = nos::sys::vulkan;

NOS_REGISTER_NAME(Output)
NOS_REGISTER_NAME(Color)
NOS_REGISTER_NAME(Resolution)

struct Fill : nos::NodeContext
{
    using nos::NodeContext::NodeContext;

    nosResult ExecuteNode(nos::NodeExecuteParams const& args) override
    {
        auto resolution = *args.GetPinValue<nosVec2u>(NSN_Resolution);
        auto color      = *args.GetPinValue<nosVec4>(NSN_Color);
        if (resolution.x == 0 || resolution.y == 0)
            return NOS_RESULT_SUCCESS;

        auto tex     = args.GetPinObject<vkss::Texture>(NSN_Output);
        auto texInfo = vkss::GetResourceInfo(tex);

        if (!texInfo || texInfo->Width != resolution.x || texInfo->Height != resolution.y)
        {
            nosTextureInfo ti{
                .Width  = resolution.x,
                .Height = resolution.y,
                .Format = NOS_FORMAT_R8G8B8A8_UNORM,
                .Usage  = nosImageUsage(NOS_IMAGE_USAGE_SAMPLED | NOS_IMAGE_USAGE_RENDER_TARGET)};

            tex = vkss::CreateTexture(ti, "Fill Output");
            if (!tex)
                return NOS_RESULT_FAILED;
            SetPinObject(NSN_Output, tex);
        }

        auto cmd = vkss::BeginCmd(NOS_NAME("Fill"), NodeId);
        nosVulkan->Clear(cmd, tex, color);
        vkss::EndCmd(cmd);

        return NOS_RESULT_SUCCESS;
    }
};

nosResult RegisterFill(nosNodeFunctions* outFunctions)
{
    NOS_BIND_NODE_CLASS(NOS_NAME("mycorp.myplugin.Fill"), Fill, outFunctions)
    return NOS_RESULT_SUCCESS;
}

}
```

A few things worth pointing out:

**`BeginCmd` takes your node's id.** Passing `NodeId` associates the commands with the node, which
is what makes them identifiable in GPU captures and profiling. The name is the debug label — make
it identify the node.

**Pin objects, not pin values.** A texture is not copied into your node. `GetPinObject<T>` returns
a `TypedObjectRef<T>`, a counted reference to an engine-owned resource. `SetPinObject` publishes a
new one when you have to reallocate.

**Resize by checking, not by assuming.** `GetResourceInfo` returns `std::nullopt` when the pin has
no resource yet, so the "create it" and "resize it" cases collapse into one branch.

## 3. Decide whether to submit

`EndCmd(cmd, forceSubmit)` defaults `forceSubmit` to `false`, and that default is correct for
ordinary nodes.

Recorded commands do not execute until the buffer is submitted, and the engine batches submissions
across a path. Submitting per node costs real performance.

Pass `true` only when you must synchronise — when the CPU needs the result, or when you are handing
the resource to another graphics API or process. Command buffers used outside the scheduler thread
are submitted regardless.

## 4. Wait for the GPU, when you have to

`EndCmd` does not wait. To know the GPU finished, ask for an event and wait on it:

```cpp
nosGPUEvent event{};
vkss::EndCmd(cmd, /*forceSubmit=*/true, &event);
nosVulkan->WaitGpuEvent(&event, UINT64_MAX);
```

!!! danger "Two ways to get this wrong"
    Requesting an event does **not** submit the buffer. Waiting on an event whose command buffer
    was never submitted times out or deadlocks — so pass `forceSubmit = true` whenever you ask for
    one and intend to wait.

    Every event handed back must eventually reach `WaitGpuEvent`, or it leaks. A timeout of `0`
    deletes the event without waiting, which is the correct way to discard one.

## 5. Manage resources

Create through the helpers, which return reference-counted handles:

```cpp
auto tex = vkss::CreateTexture(textureInfo, "MyTexture");
auto buf = vkss::CreateBuffer(bufferInfo, "MyBuffer");
```

There is no matching destroy call to remember. The resource is released when the last reference
goes out of scope — see [Objects and the type system](../explanation/objects-and-types.md).

`vkss::ImportExternalResource` brings in a handle from another API or process, which is how
cross-process texture sharing works. `nosVulkan->Map` returns a CPU pointer for a buffer.

## 6. Run a shader pass

Register the shader and pass once — plugin initialisation is the right place — then run it per
frame:

```cpp
nosShaderInfo shader{};   // source path, source text, or SPIR-V blob
nosVulkan->RegisterShaders(1, &shader);

nosPassInfo pass{};       // globally unique PassName + shader(s)
nosVulkan->RegisterPasses(1, &pass);
```

Then `RunPass`, `RunPass2` or `RunComputePass` inside a recorded command buffer, binding pins to
shader parameters with the `ShaderBinding` helpers:

```cpp
std::array bindings = {
    vkss::ShaderTextureBinding(NOS_NAME("Input"), inputTex, NOS_TEXTURE_FILTER_LINEAR),
    vkss::ShaderDataBinding(NOS_NAME("Gain"), gain),
};
```

`PassName` must be globally unique across every loaded module — prefix it with your plugin name.

If the pass is a straightforward filter over its inputs, you probably do not need any of this:
[write a shader-only node](write-a-shader-node.md) and skip the C++ entirely.

## Common mistakes

**Not checking subsystem availability.** On the manual request path, `RequestSubsystem` fails when
a compatible version is not installed. Check the result rather than dereferencing a null pointer
later.

**Forcing submission every frame in every node.** It is a significant performance hit. Leave
`forceSubmit` at its default.

**Leaking GPU events.** Every event from `EndCmd` needs a `WaitGpuEvent`, even if only to delete
it.

**Assuming a recorded command has run.** It has not. Nothing runs until the buffer is submitted and
the GPU reaches it.
