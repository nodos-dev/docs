# nos.sys.vulkan

The Vulkan subsystem gives plugins access to GPU resources, command recording, shaders, passes and
swapchains.

Describes `nos.sys.vulkan` **8.0** on Nodos {{ nodos_version }}.

!!! warning "This API changed in {{ nodos_version }}"
    Version 8.0 takes **object handles** (`nosResourceObject`, `nosTextureObject`) and parameter
    structs where earlier versions took `nosResourceShareInfo*` and loose arguments. `Begin`/`End`
    now take `nosCmdBeginParams` / `nosCmdEndParams`, and the separate `End2` is gone — request a
    GPU event through `nosCmdEndParams::OutGPUEventHandle` instead. Code written against
    {{ legacy_version }} will not compile unchanged.

## Getting the API

```json title="Manifest"
"dependencies": [ { "name": "nos.sys.vulkan", "version": "8.0" } ]
```

```cpp title="Source/PluginMain.cpp"
#include <nosSysVulkan/nosVulkanSubsystem.h>

#define NOS_DEPENDENCIES     \
    NOS_DEPENDENCY(NOS_VULKAN)
```

The global `nosVulkan` is then available wherever the header is included. See
[Use the Vulkan subsystem](../../how-to/use-the-vulkan-subsystem.md).

| Header | Contents |
|---|---|
| `<nosSysVulkan/nosVulkanSubsystem.h>` | The API struct, types and macros. |
| `<nosSysVulkan/Helpers.hpp>` | C++ helpers in `nos::sys::vulkan` (aliased `nos::vkss`). |
| `<nosSysVulkan/Types_generated.h>` | FlatBuffers types, including `Texture` and `Buffer`. |

Prefer the helpers. They fill in the parameter structs and return RAII object references.

## C++ helpers

Namespace `nos::sys::vulkan`.

| Helper | Returns |
|---|---|
| `BeginCmd(nos::Name name, nos::uuid nodeId)` | `nosCmd`. Records the associated node for profiling. |
| `EndCmd(nosCmd, nosBool forceSubmit = false, nosGPUEvent* outEvent = nullptr)` | `void` |
| `CreateTexture(nosTextureInfo, const char* tag)` | `TypedObjectRef<Texture>` |
| `CreateTexture3D(...)` | `TypedObjectRef<Texture3D>` |
| `CreateBuffer(nosBufferInfo, ...)` | `TypedObjectRef<Buffer>` |
| `CreateResource(nosResourceInfo const&, ...)` | `ForeignObjectRef` |
| `ImportExternalResource(nosResourceInfo const&, nosExternalMemoryInfo const&, const char* tag)` | `ForeignObjectRef` |
| `GetResourceInfo(TypedObjectRef<T> const&)` | `std::optional<...Info>` — `nullopt` when the pin holds no resource. |
| `GetResourceFieldType(nosResourceObject)` | `nosTextureFieldType` |
| `GetTextureSizeInBytes(nosTextureInfo)` | `uint64_t` |
| `ShaderDataBinding(nosName, T&)` | `nosShaderBinding` |
| `ShaderTextureBinding(nosName, nosTextureObject, nosTextureFilter)` | `nosShaderBinding` |
| `ShaderBufferBinding(nosName, nosBufferObject)` | `nosShaderBinding` |
| `ShaderTextureArrayBinding(nosName, nosTextureObject*, nosTextureFilter*, uint32_t)` | `nosShaderBinding` |
| `ShaderTextureBindingFromPin(nosUUID pinId, ...)` | `nosShaderBinding` |
| `IsTextureFieldTypeInterlaced(nosTextureFieldType)` | `bool` |
| `FlippedField(nosTextureFieldType)` | `nosTextureFieldType` |
| `GetComponentBytesFromTextureFormat(nosFormat)` | `unsigned short` |
| `GetNumberOfComponentsFromTextureFormat(nosFormat)` | `unsigned short` |

## Command recording

Most calls record into a `nosCmd` and are not synchronised between CPU and GPU. Nothing executes
until the command buffer is submitted.

### `Begin`

```c
nosResult Begin(const nosCmdBeginParams* beginParams);
```

```c
typedef struct nosCmdBeginParams
{
    nosName Name;                       // debug label for recorded commands
    nosUUID AssociatedNodeId;           // node sending the commands, if applicable
    nosCmd* OutCmdHandle;               // filled with the handle to use for subsequent calls
    nosCmdQueueType PreferredQueueType;
} nosCmdBeginParams;
```

Use `vkss::BeginCmd(name, NodeId)` rather than filling this in by hand.

### `End`

```c
nosResult End(nosCmd, const nosCmdEndParams* endParams);
```

```c
typedef struct nosCmdEndParams
{
    nosBool ForceSubmit;                // default NOS_FALSE
    nosGPUEvent* OutGPUEventHandle;     // optional; signalled when the GPU completes
} nosCmdEndParams;
```

`ForceSubmit`
:   Submits the buffer to the GPU. Recorded commands do not execute until submission, and ordinary
    nodes on a path can leave this false — the engine batches. Submitting has a significant
    performance cost. Set it true only when the CPU needs the result, or when handing a resource to
    another graphics API. Command buffers used outside the scheduler thread are submitted
    regardless.

`OutGPUEventHandle`
:   Filled with an event signalled on GPU completion. **This does not submit the buffer**; waiting
    on an event whose buffer was never submitted times out or deadlocks. Every event returned must
    eventually reach [`WaitGpuEvent`](#waitgpuevent), or it leaks.

### `FlushCommands`

```c
void FlushCommands();
```

## Resources

### `CreateResource`

```c
nosResult CreateResource(const nosResourceInfo* resourceInfo,
                         const nosExternalMemoryHandleType* optExportHandleTypes,
                         const char* tag,
                         nosObjectReference* outResource);
```

`tag` is a debug label. Prefer `vkss::CreateTexture` / `vkss::CreateBuffer`, which return
reference-counted handles with no matching destroy call to remember.

### `ImportResource`

```c
nosResult ImportResource(const nosResourceInfo* resourceInfo,
                         const nosExternalMemoryInfo* importInfo,
                         const char* tag,
                         nosObjectReference* outResource);
```

Brings in memory from another API or process — the basis of cross-process texture sharing.

### `GetResourceInfo`

```c
nosResult GetResourceInfo(nosResourceObject handle,
                          nosResourceInfo* outInfo,
                          nosExternalMemoryInfo* outExportInfo);
```

### `Map`

```c
uint8_t* Map(nosBufferObject buffer);
```

CPU pointer to a buffer's memory.

### Other resource calls

| Function | Purpose |
|---|---|
| `GetColorTexture(nosVec4 color, nosObjectReference* out)` | A 1×1 texture of a solid colour. |
| `GetStockTexture(nosObjectReference* out)` | A stock texture. |
| `IsStockTexture(nosTextureObject, nosStockTexture* outWhich)` | Whether a texture is a stock one. |
| `IsBlitCompatible(nosFormat src, nosFormat dst)` | Whether `Copy` supports this format pair. |
| `SetResourceFieldType(nosResourceObject, nosTextureFieldType)` | Set interlacing field type. |
| `GetResourceFieldType(nosResourceObject, nosTextureFieldType* out)` | Read it back. |
| `GetPinTextureFilter(nosUUID pinId, nosTextureFilter* out)` | The filter configured on a pin. |
| `ResourcePoolGarbageCollect()` | Force-free unused pooled resources. Undoes pool optimisations — call only when genuinely needed. |

### Resource types

```c
enum nosResourceType
{
    NOS_RESOURCE_TYPE_BUFFER  = 1,
    NOS_RESOURCE_TYPE_TEXTURE = 2,
};

struct nosResourceInfo
{
    nosResourceType Type;
    union {
        nosTextureInfo Texture;
        nosBufferInfo  Buffer;
    };
};
```

`Type` must match whichever union member is populated.

## Operations

### `Copy`

```c
nosResult Copy(nosCmd, nosResourceObject src, nosResourceObject dst, const nosCopyParams* params);
```

```c
typedef struct nosCopyParams
{
    nosTextureFilter TextureFilter;   // used when blitting between different sizes; LINEAR if params omitted
    uint32_t RegionCount;
    const nosCopyRegion* Regions;
} nosCopyParams;
```

Check [`IsBlitCompatible`](#other-resource-calls) when the formats differ.

### `Clear`

```c
nosResult Clear(nosCmd, nosTextureObject texture, nosVec4 color);
```

### `Download`

```c
nosResult Download(nosCmd, nosTextureObject texture,
                   nosObjectReference* outBuffer, const char* outBufferTag);
```

### `ImageLoad`

```c
nosResult ImageLoad(nosCmd, const void* buf, nosVec2u extent, nosFormat format,
                    nosTextureObject dstImg, nosTextureFilter filterIfBlit);
```

## Shaders and passes

### Compiling and registering

A shader is provided to `ShaderInfo2.Source` as one of: a human-readable HLSL or GLSL source path,
source text, a SPIR-V blob path, or SPIR-V blob data.

```c
nosResult RegisterShaders(size_t count, nosShaderInfo* shaders);
nosResult RegisterPasses(size_t count, nosPassInfo* passInfos);
```

A pass needs a **globally unique** `PassName` — prefix it with your module name. For a render pass,
the fragment shader goes in `nosPassInfo.Shader` and the optional vertex shader in
`nosPassInfo.VertexShader`; omitting the vertex shader uses a full-quad default. Compute shaders
form a compute pass.

### Running

```c
nosResult RunPass(nosCmd, const nosRunPassParams* params);
nosResult RunPass2(nosCmd, const nosRunPass2Params* params);
nosResult RunPass3(nosCmd, const nosRunPass3Params* params);
nosResult RunComputePass(nosCmd, const nosRunComputePassParams* params);
```

Bind pins to shader parameters with the `Shader*Binding` helpers.

### Shader-only nodes

A node with a `contents` block of type `nos.sys.vulkan.GPUNode` needs no C++ at all — no binary, no
exported node functions. The `shader` path is relative to the plugin's manifest; if the extension is
not `.spv`, the subsystem compiles it with whichever of `glslc` and `dxc` succeeds.

```json
"contents": {
    "type": "nos.sys.vulkan.GPUNode",
    "options": {
        "shader": "../Shaders/ColorCorrect.hlsl",
        "stage": "FRAGMENT"
    }
}
```

See [Write a shader-only node](../../how-to/write-a-shader-node.md).

`ExecuteGPUNode(void* ctx, nosNodeExecuteParams* params)` is the entry point the subsystem uses for
these.

## Synchronisation

### `WaitGpuEvent`

```c
nosResult WaitGpuEvent(nosGPUEvent* eventHandle, uint64_t timeoutNs);
```

Waits for the GPU to complete work up to the given event, then deletes the event and sets the
handle to null.

`timeoutNs`
:   Nanoseconds. `UINT64_MAX` waits indefinitely. **`0` deletes the event without waiting**, which
    is the correct way to discard one you no longer need.

### Semaphores and events

| Function | Purpose |
|---|---|
| `CreateSemaphore(const nosSemaphoreCreateInfo*, nosObjectReference* out)` | Create a semaphore. |
| `ExportSemaphore(nosSemaphoreObject, nosSemaphoreExportInfo* out)` | Export for cross-process or cross-API use. |
| `AddSignalSemaphoreToCmd(nosCmd, nosSemaphoreObject, uint64_t value)` | Signal on completion. |
| `AddWaitSemaphoreToCmd(nosCmd, nosSemaphoreObject, uint64_t value)` | Wait before executing. |
| `SignalSemaphore(nosSemaphoreObject, uint64_t value)` | Signal from the CPU. |
| `CreateGPUEventHolder(nosObjectReference* out)` | Create an event holder object. |
| `GetGPUEventFromHolder(nosGPUEventHolder, nosGPUEvent** out)` | Extract the event. |

## Swapchain and surface

For modules presenting to a window directly.

| Function | Purpose |
|---|---|
| `CreateWindowSurface(void* windowHandle, nosObjectReference* out)` | Surface from a native window handle. |
| `CreateSwapchain(const nosSwapchainCreateInfo*, nosObjectReference* out, uint32_t* outImgCount)` | Create a swapchain. Access must be externally synchronised. |
| `SwapchainAcquireNextImage(nosSwapchainObject, uint64_t timeoutNs, uint32_t* outIndex, nosSemaphoreObject toSignal)` | Acquire the next image. May block up to `timeoutNs`. |
| `SwapchainPresent(nosSwapchainObject, uint32_t imageIndex, nosSemaphoreObject toWait)` | Present. |
| `GetSwapchainImages(nosSwapchainObject, nosObjectReference* images)` | Retrieve the images. |
| `ImageStateToPresent(nosCmd, nosTextureObject)` | Transition an image to present state. |

!!! note
    If `SwapchainAcquireNextImage` is given a semaphore rather than null, the CPU can run ahead of
    the GPU. Wait for the GPU periodically or you will exhaust command resources.

## Legacy API

The Nodos {{ legacy_version }} version of this subsystem had a different shape:
`Begin(const char* name, nosCmd* outCmd)`, `End(nosCmd, nosBool forceSubmit)`, a separate
`End2(nosCmd, nosBool, nosGPUEvent*)`, and `Copy`/`Clear`/`CreateResource` taking
`nosResourceShareInfo*`. The include path was `<nosVulkanSubsystem/...>` and the dependency was
requested with `nosEngine.RequestSubsystem`.

See [Migrate a plugin to {{ nodos_version }}](../../how-to/migrate-1-3-to-1-4.md).
