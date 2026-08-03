# Connect an external application

An application that links the Nodos **Application SDK** connects to a running engine over gRPC and
appears in the graph as a node. From then on it can be wired to other nodes, and its pins can be
driven from the editor.

One process gets one node. The application can modify that node — add pins, change values — but it
cannot create additional nodes.

This is the right integration when the code cannot live inside the engine process: an existing
renderer, a different graphics API, a separate release cycle. If your code *can* live in-process,
[write a plugin](../tutorials/your-first-plugin.md) instead — it is simpler and faster.

## 1. Locate the SDK

The Application SDK versions independently of the engine. Have your build system locate it and fail
early if it is missing:

```shell
nodos sdk-info {{ process_sdk_version }}.0 process
```

It prints JSON describing the installed SDK and fails if no such version is present, so it drops
straight into a build script. The engine's own value is `process_sdk_version` in `SDK/info.json`
under the engine install:

```json title="Engine/<version>/SDK/info.json"
{
	"version": "{{ nodos_version }}.0",
	"plugin_sdk_version": "{{ plugin_sdk_version }}.0",
	"process_sdk_version": "{{ process_sdk_version }}.0"
}
```

## 2. Include the headers

Every header you need is under `Include/` in the directory printed above — the SDK headers and the
generated FlatBuffers ones. Add it to your include path.

The headers require {{ cpp_version }}, so your project must target at least that.

## 3. Load the library

`nosAppSDK` is loaded at runtime, not linked. Load it however your platform does, then hand the
SDK a loader instead of resolving symbols yourself:

```cpp title="Loading on Windows"
struct WinProcLoader final : nos::app::IAppApiProcLoader
{
    HMODULE Module;
    explicit WinProcLoader(HMODULE module) : Module(module) {}
    ~WinProcLoader() { ::FreeLibrary(Module); }

    ProcFuncPtr GetProcAddress(const char* name) const override
    {
        return reinterpret_cast<ProcFuncPtr>(::GetProcAddress(Module, name));
    }
};

HMODULE sdk = LoadLibraryA(sdkDllPath.c_str());
auto loader = std::make_unique<WinProcLoader>(sdk);
```

The SDK resolves `CheckSDKCompatibility`, `MakeAppServiceClient` and `ShutdownClient` through that,
and refuses to start if the library disagrees with the version your headers declare. Keep the
loader alive as long as anything created from it.

## 4. Implement the application and its node

Two interfaces. `IApp` is your process; `IAppNode` is the node the engine created for it.

```cpp
struct MyAppNode : nos::app::IAppNode
{
    void OnImport(nos::fb::Node const& node) override;         // learn your pins
    void OnPinValueChanges(
        std::unordered_map<nos::uuid, nos::Buffer> const& values) override;
    void OnPreExecute(void* frameCtx, uint64_t frameNumber) override;
    void OnPostExecute(void* frameCtx, uint64_t frameNumber) override;
};

struct MyApp : nos::app::IApp
{
    nos::app::IAppNode& CreateAppNode_ApiThread() override { return *(new MyAppNode(*this)); }
    void DestroyAppNode(nos::app::IAppNode& node) override { delete static_cast<MyAppNode*>(&node); }
};
```

Only those two `IApp` methods are required; every other callback on both interfaces has a default,
so override what you need and ignore the rest. The full list is in
[Application SDK](../reference/app-sdk.md#callbacks).

`OnImport` is generally the first thing you see, and it is where you find out which pins your node
has.

!!! info "Which thread a callback runs on"
    `CreateAppNode_ApiThread` and the other `_ApiThread` callbacks run on the SDK's thread.
    Everything else arrives inside your own `PreExecute` call, on your thread — so ordinary node
    callbacks need no locking against your frame work.

## 5. Create the communicator and drive it

```cpp
nosApplicationInfo appInfo{ .AppKey = "MyCorp-MyApp", .AppName = "My App" };

auto communicator = nos::app::NodosCommunicator::Create(
    myApp, *loader, "localhost:50053", appInfo);

if (auto* err = communicator.Error())
    return Fail(*err);
```

`NodosCommunicator` handles connecting and reconnecting, so there is no connect loop to write. Call
it once per frame from your own loop:

```cpp
while (running)
{
    if (nodos->PreExecute(&frameCtx))
        RenderForNodos(frameCtx);   // the engine asked for this frame
    else
        RenderNormally();           // not connected, or not driving us

    nodos->PostExecute(&frameCtx);
}
```

`PreExecute` also runs anything you handed to `EnqueueTask`, and delivers the node callbacks. Its
methods are not internally synchronised, so drive it from one thread.

## 6. Run it

Start an engine listening at the address you passed:

```shell
nodos launch
```

The name from `AppName` appears in the editor's **Apps** pane. Drag it into a graph and the engine
creates your node — `CreateAppNode_ApiThread` fires, then `OnImport`. Wire it up like any other
node.

The app service listens on `0.0.0.0:50053` by default. To move it:

```shell
nosLauncher --override-settings connection_settings/app_service_address="0.0.0.0:50553"
```

## Sample applications

Two complete samples ship with the toolchain:

```shell
nodos get-sample vk_app  --output-dir ./samples
nodos get-sample dx12_app --output-dir ./samples
```

Both follow the same arc, which is a reasonable template for your own integration:

1. Create a window and initialise the graphics API.
2. Wait for a connection to Nodos.
3. Add an input and an output pin to the application node.
4. Get a texture handle from the input pin.
5. Render on top of it and present it in the application window.
6. Send the rendered texture back through the output pin.

Note that Nodos has no DirectX 12 backend of its own — the DX12 sample demonstrates
cross-API texture sharing, which is the interesting part.

There is also a maintained **Unreal Engine 5** integration, *Nodos Link*, at
[github.com/mediaz/ue5plugin](https://github.com/mediaz/ue5plugin).

## See also

- [Application SDK reference](../reference/app-sdk.md)
- [Extension model](../explanation/extension-model.md) — plugins vs subsystems vs applications
