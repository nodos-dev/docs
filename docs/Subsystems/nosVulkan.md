# nosVulkan Subsystem

nosVulkan subsystem features an API for plugins to communicate with vulkan & send commands to the GPU.

## Minimal example
For a plugin or a subsystem, in the file that contains the ``MZ_INIT`` macro, include ``<nosVulkanSubsystem/nosVulkanSubsystem.h>`` for nosVulkan API, then in the ``nosExportNodeFunctions`` function request the nosVulkan subsystem using ``nosEngine.RequestSubsystem`` function. Then `nosVulkan` global variable can be used anywhere to communicate with the nosVulkan API. ``<nosVulkanSubsystem/Helpers.hpp>`` contains helper functions and ``<nosVulkanSubsystem/Types_generated.h>`` contains flatbuffers headers for Texture.

```cpp title="Test.cpp"

#include <Nodos/PluginAPI.h>

#include <nosVulkanSubsystem/nosVulkanSubsystem.h>
#include <nosVulkanSubsystem/Helpers.hpp>

NOS_INIT();
nosVulkanSubsystem* nosVulkan = nullptr;//nosVulkan is a variable that is declared as extern in nosVulkanSubsystem.h
extern "C"
{

	NOSAPI_ATTR nosResult NOSAPI_CALL nosExportNodeFunctions(size_t* outCount, nosNodeFunctions** outFunctions)
	{
		*outCount = (size_t)(1);
		if (!outFunctions)
			return NOS_RESULT_SUCCESS;
		auto ret = nosEngine.RequestSubsystem(NOS_NAME_STATIC(NOS_VULKAN_SUBSYSTEM_NAME), 1, 0, (void**)&nosVulkan);
//nosEngine.RequestSubsystem(nosName subsystemName, int subsystemVersionMajor, int subsystemVersionMinor, void** outSubsystemContextPtr)
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

## Functions
Most operations in nosVulkan API uses a ``nosCmd`` struct to record commands and most calls are not synchronized between CPU and GPU.

---
### Begin
``nosResult Begin(const char* name, nosCmd* outCmd)``<br>
Parameters:<br>
``name``: Debug name for the commands that will be recorded using this cmd.<br>
``outCmd``: Filled with the handle for a command buffer that can be used with other calls.
---
### End
``nosResult End(nosCmd cmd, nosBool forceSubmit);``<br>
Marks the end of command buffer's use.<br>
Parameters:<br>
``forceSubmit``: Submits the command buffer to the GPU. Recorded commands are not executed until the command buffer is submitted to the GPU, regular nodes in the node path can get away with not submitting the command buffer. Nodes that communicate between the CPU and the GPU or other graphics API's needs to submit the command buffer in appopriate points. Mind that submitting the command buffer has a significant performance hit. This does not wait for the GPU, refer to [End2](#end2). Command buffers used outside of the Scheduler thread are submitted even if this parameter is false. 
- - -
### End2
``nosResult End2(nosCmd cmd, nosBool forceSubmit, nosGPUEvent* outEventHandle); // TODO: Merge Begin and Begin2 functions with nosBeginCmdParams.``
Marks the end of command buffer's use.<br>
Parameters:<br>
``forceSubmit``: Submits the command buffer to the GPU. Command buffers used outside of the Scheduler thread are submitted even if this parameter is false. Refer to [End](#end) for more detailed information.<br>
``outEventHandle``: If not null, fills the value with an event that will be signalled when the GPU completes execution of the commands in the command buffer. Mind that this does not submits the command buffer to GPU unless ``forceSubmit`` is ``true``, waiting it before the command buffer is submitted will result in a timeout or deadlock. Returned event must be waited at some point using [WaitGpuEvent](#waitgpuevent), unless the event results in a leak.
- - -
``nosResult Copy(nosCmd, const nosResourceShareInfo* src, const nosResourceShareInfo* dst, const char* benchmark); // benchmark as string?``
- - -
``nosResult RunPass(nosCmd, const nosRunPassParams* params);``<br>
- - -
``nosResult RunPass2(nosCmd, const nosRunPass2Params* params);``
- - -
``nosResult RunComputePass(nosCmd, const nosRunComputePassParams* params);``
- - -
``nosResult Clear(nosCmd, const nosResourceShareInfo* texture, nosVec4 color);``
- - -
``nosResult Download(nosCmd, const nosResourceShareInfo* texture, nosResourceShareInfo* outBuffer);``
- - -
``nosResult ImageLoad(nosCmd, const void* buf, nosVec2u extent, nosFormat format, nosResourceShareInfo* inOut);``
- - -
``nosResult CreateResource(nosResourceShareInfo* inout);``
- - -
``nosResult ImportResource(nosResourceShareInfo* inout);``
- - -
``nosResult DestroyResource(const nosResourceShareInfo* resource);``
- - -
``nosResult ReloadShaders(nosName nodeName);``
- - -
``uint8_t* Map(const nosResourceShareInfo* buffer);``
- - -
``nosResult GetColorTexture(nosVec4 color, nosResourceShareInfo* out);``
- - -
``nosResult GetStockTexture(nosResourceShareInfo* out);``
- - -
``nosResult CreateSemaphore(uint64_t pid, uint64_t externalOSHandle, nosSemaphore* outSemaphore);``
- - -
``nosResult DestroySemaphore(nosSemaphore semaphore);``
- - -
``nosResult AddSignalSemaphoreToCmd(nosCmd cmd, nosSemaphore semaphore, uint64_t signalValue);``
- - -
``nosResult AddWaitSemaphoreToCmd(nosCmd cmd, nosSemaphore semaphore, uint64_t waitValue);``
- - -
``nosResult SignalSemaphore(nosSemaphore semaphore, uint64_t value);``
- - -
``nosResult RegisterShaders(size_t count, nosShaderInfo* shaders);``
- - -
``nosResult RegisterPasses(size_t count, nosPassInfo* passInfos); // ABI breaks on nosPassInfo struct size change.``
- - -
### WaitGpuEvent
``nosResult WaitGpuEvent(nosGPUEvent* eventHandle, uint64_t timeoutNs);``<br>
Waits for the gpu to complete the work until the given event or timeout, then deletes the event.
Parameters:<br>
``eventHandle``: Event handle to wait, will be set to null afterwards.<br>
``timeoutNs``: Timeout in nanoseconds, pass UINT64_T for max and 0 for deleting the event without any wait.<br>