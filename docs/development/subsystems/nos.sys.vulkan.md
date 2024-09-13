#  Vulkan Subsystem

Subsystem `nos.sys.vulkan` features an API for plugins to communicate with vulkan & send commands to the GPU.

## Minimal example
For a plugin or a subsystem, to define a dependency to nosVulkan, add the `nos.sys.vulkan` dependency in the noscfg file as shown in ``Test.noscfg``. Then in the file that contains the ``NOS_INIT`` macro, include ``<nosVulkanSubsystem/nosVulkanSubsystem.h>`` for `nos.sys.vulkan` API, then in the ``nosExportNodeFunctions`` function request the Vulkan subsystem using ``nosEngine.RequestSubsystem`` function. Then `nosVulkan` global variable can be used anywhere to communicate with the `nos.sys.vulkan` API. ``<nosVulkanSubsystem/Helpers.hpp>`` contains helper functions and ``<nosVulkanSubsystem/Types_generated.h>`` contains flatbuffers headers for Texture.

```json title="Test.noscfg"
{
    "info": {
        "id": {
            "name": "nos.test",
            "version": "1.0.0"
        },
        "display_name": "Test",
        "description": "Test plugin.",
        "dependencies": [
            {
                "name": "nos.sys.vulkan",
                "version": "1.0.0"
            }
        ]
    },
	"node_definitions":...
}
```

```cpp title="Test.cpp"

#include <Nodos/PluginAPI.h>

#include <nosVulkanSubsystem/nosVulkanSubsystem.h>
#include <nosVulkanSubsystem/Helpers.hpp>

NOS_INIT();
nosVulkanSubsystem* `nos.sys.vulkan` = nullptr;//`nos.sys.vulkan` is a variable that is declared as extern in nosVulkanSubsystem.h
extern "C"
{

	NOSAPI_ATTR nosResult NOSAPI_CALL nosExportNodeFunctions(size_t* outCount, nosNodeFunctions** outFunctions)
	{
		*outCount = (size_t)(1);
		if (!outFunctions)
			return NOS_RESULT_SUCCESS;
		auto ret = nosEngine.RequestSubsystem(NOS_NAME_STATIC(NOS_VULKAN_SUBSYSTEM_NAME), 1, 0, (void**)&nosVulkan);
		//System might not have nosVulkanSubsystem with the requested version, so be sure to check for it.
		if (ret != NOS_RESULT_SUCCESS)
			return ret;
		//Register nodes etc...
		outFunctions[0]->ClassName = NOS_NAME_STATIC("nos.test.CopyTestLicensed");
		outFunctions[0]->ExecuteNode = [](void* ctx, const nosNodeExecuteArgs* args)
		{
			nosCmd cmd;
			nosVulkan->Begin("(nos.test.CopyTest) Copy", &cmd);
			auto values = nos::GetPinValues(args);
			nosResourceShareInfo input = nos::vkss::DeserializeTextureInfo(values[NOS_NAME_STATIC("Input")]);
			nosResourceShareInfo output = nos::vkss::DeserializeTextureInfo(values[NOS_NAME_STATIC("Output")]);
			nosVulkan->Copy(cmd, &input, &output, 0);
			nosVulkan->End(cmd, NOS_FALSE);
			return NOS_RESULT_SUCCESS;
		};
		return NOS_RESULT_SUCCESS;
	}
}
```

!!! warning
	Don't forget to check for the availability of the subsystem. Since the subsystem may not be available.

## Shaders

### Compiling & Registering
There are 2 ways of compiling and registering a shader. One is by defining it in a Shader Only Node and another is by registering it in ```registerXXX()``` calls.
To be able to execute shaders, a related ```ShaderPass``` should be created. Compute shaders should create ```ComputePass```, fragment and vertex shader should create ```RenderPass```. A ```RenderPass``` has to have a fragment shader but vertex shader is optional (if not specified, full quad vertex shader is used).

#### Shader Only Nodes
To add a shader only node(such as `Color Correct`), add the node to plugin's noscfg and create a nosdef for the node. In the nosdef, add pins and other fields as if the node is a regular node. Then, in the node definition, fill the ``#!json "contents`` field as shown in the example. The path given in ``#!json shader`` field is relative to the plugin's noscfg file. If the file extension doesn't end with `.spv`, `nos.sys.vulkan` tries to compile the given file using glslc and dxc, whichever compiles. Shader only nodes do not need a .dll file and the plugin doesn't need to export their node functions.
```json
{
    "nodes": [
        {
            "class_name": "ColorCorrect",
            "contents_type": "Job",
            "contents": {
                "type": "nos.sys.vulkan.GPUNode",
                "options": {
                    "shader": "../Shaders/ColorCorrect.hlsl",
                    "stage": "FRAGMENT"
                }
            },
			"pins": ...
		}
	]
}
```
#### Registering a shader or a GPU pass
To compile a shader, caller should provide either human-readable (either HLSL or GLSL) source file path, human-readable source file text, SPIR-V blob file path or SPIR-V blob data to ```ShaderInfo2.Source```.
To create a pass, a globally unique `PassName` and shaders should be provided. To create a RenderPass, fragment shader should be passed to ```nosPassInfo.Shader``` and vertex shader (optional) should be passed to ```nosPassInfo.VertexShader```.

## Types
### nosResourceType
```cpp
enum nosResourceType
{
	NOS_RESOURCE_TYPE_BUFFER = 1,
	NOS_RESOURCE_TYPE_TEXTURE = 2,
}
```
Refer to [nosResourceShareInfo]().
### nosResourceInfo
```cpp
struct nosResourceInfo
{
	nosResourceType Type;
	union {
		nosTextureInfo Texture;
		nosBufferInfo Buffer;
	};
};
```
``#!c Type`` must be set to adequate ``#!c nosResourceType`` based on which resource info is used.

## Functions
Most operations in `nos.sys.vulkan` API uses a ``nosCmd`` struct to record commands and most calls are not synchronized between CPU and GPU.

---

### Begin
``#!c nosResult Begin(const char* name, nosCmd* outCmd)``<br>
Parameters:<br>
``name``: Debug name for the commands that will be recorded using this cmd.<br>
``outCmd``: Filled with the handle for a command buffer that can be used with other calls.

---
### End
``#!c nosResult End(nosCmd cmd, nosBool forceSubmit);``<br>
Marks the end of command buffer's use.<br>
Parameters:<br>
``forceSubmit``: Submits the command buffer to the GPU. Recorded commands are not executed until the command buffer is submitted to the GPU, regular nodes in the node path can get away with not submitting the command buffer. Nodes that communicate between the CPU and the GPU or other graphics API's needs to submit the command buffer in appopriate points. Mind that submitting the command buffer has a significant performance hit. This does not wait for the GPU, refer to [End2](#end2). Command buffers used outside of the Scheduler thread are submitted even if this parameter is false. 
- - -
### End2
``#!c nosResult End2(nosCmd cmd, nosBool forceSubmit, nosGPUEvent* outEventHandle);``
Marks the end of command buffer's use.<br>
Parameters:<br>
``forceSubmit``: Submits the command buffer to the GPU. Command buffers used outside of the Scheduler thread are submitted even if this parameter is false. Refer to [End](#end) for more detailed information.<br>
``outEventHandle``: If not null, fills the value with an event that will be signalled when the GPU completes execution of the commands in the command buffer. Mind that this does not submits the command buffer to GPU unless ``forceSubmit`` is ``true``, waiting it before the command buffer is submitted will result in a timeout or deadlock. Returned event must be waited at some point using [WaitGpuEvent](#waitgpuevent), unless the event results in a leak.
- - -
``#!c nosResult Copy(nosCmd, const nosResourceShareInfo* src, const nosResourceShareInfo* dst, const char* benchmark);``
- - -
``#!c nosResult RunPass(nosCmd, const nosRunPassParams* params);``<br>
- - -
``#!c nosResult RunPass2(nosCmd, const nosRunPass2Params* params);``
- - -
``#!c nosResult RunComputePass(nosCmd, const nosRunComputePassParams* params);``
- - -
``#!c nosResult Clear(nosCmd, const nosResourceShareInfo* texture, nosVec4 color);``
- - -
``#!c nosResult Download(nosCmd, const nosResourceShareInfo* texture, nosResourceShareInfo* outBuffer);``
- - -
``#!c nosResult ImageLoad(nosCmd, const void* buf, nosVec2u extent, nosFormat format, nosResourceShareInfo* inOut);``
- - -
``#!c nosResult CreateResource(nosResourceShareInfo* inout);``
- - -
``#!c nosResult ImportResource(nosResourceShareInfo* inout);``
- - -
``#!c nosResult DestroyResource(const nosResourceShareInfo* resource);``
- - -
``#!c nosResult ReloadShaders(nosName nodeName);``
- - -
``#!c uint8_t* Map(const nosResourceShareInfo* buffer);``
- - -
``#!c nosResult GetColorTexture(nosVec4 color, nosResourceShareInfo* out);``
- - -
``#!c nosResult GetStockTexture(nosResourceShareInfo* out);``
- - -
``#!c nosResult CreateSemaphore(uint64_t pid, uint64_t externalOSHandle, nosSemaphore* outSemaphore);``
- - -
``#!c nosResult DestroySemaphore(nosSemaphore semaphore);``
- - -
``#!c nosResult AddSignalSemaphoreToCmd(nosCmd cmd, nosSemaphore semaphore, uint64_t signalValue);``
- - -
``#!c nosResult AddWaitSemaphoreToCmd(nosCmd cmd, nosSemaphore semaphore, uint64_t waitValue);``
- - -
``#!c nosResult SignalSemaphore(nosSemaphore semaphore, uint64_t value);``
- - -
``#!c nosResult RegisterShaders(size_t count, nosShaderInfo* shaders);``
- - -
``#!c nosResult RegisterPasses(size_t count, nosPassInfo* passInfos);``
- - -
### WaitGpuEvent
``#!c nosResult WaitGpuEvent(nosGPUEvent* eventHandle, uint64_t timeoutNs);``<br>
Waits for the gpu to complete the work until the given event or timeout, then deletes the event.
Parameters:<br>
``eventHandle``: Event handle to wait, will be set to null afterwards.<br>
``timeoutNs``: Timeout in nanoseconds, pass UINT64_T for max and 0 for deleting the event without any wait.<br>