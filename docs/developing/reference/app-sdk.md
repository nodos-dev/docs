# Application SDK

The Application SDK (`nosAppSDK`) lets a separate process connect to a running Nodos engine and
appear in the graph as a node. Communication is asynchronous, over gRPC, using FlatBuffers
contracts.

Describes process SDK {{ process_sdk_version }} (Nodos {{ nodos_version }}).

For a walkthrough, see
[Connect an external application](../how-to/connect-an-external-app.md).

## Model

One process gets one node. The application may modify that node — add pins, read and write values —
but it cannot create additional nodes in the graph.

The library is **loaded dynamically**, not linked. You resolve a small set of entry points and go
through them.

## Locating the SDK

```shell
nodos sdk-info {{ process_sdk_version }}.0 process
```

Prints JSON describing the installed SDK, and fails if that version is not present — which makes it
usable directly as a build-system check. Headers are under `Include/` in the reported directory,
generated FlatBuffers headers among them.

The engine's own value is `process_sdk_version` in `Engine/<version>/SDK/info.json`.

Headers require {{ cpp_version }}.

## Entry points

The library exports three symbols, their function types declared in `Nodos/AppAPI.h`:

| Symbol | Function type | Purpose |
|---|---|---|
| `CheckSDKCompatibility` | `FN_CheckSDKCompatibility` | Verify header and library agree. |
| `MakeAppServiceClient` | `FN_MakeAppServiceClient` | Create a client for an address. |
| `ShutdownClient` | `FN_ShutdownClient` | Release a client and everything it owns. |

You do not have to resolve them by hand. Implement `nos::app::IAppApiProcLoader` — one
`GetProcAddress` over your platform's loader — and the helpers in `Nodos/AppHelpers.hpp` do the
resolving and version checking:

```cpp
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
```

The compatibility check is not optional. Because the library is loaded rather than linked, a
header/library mismatch is undefined behaviour at runtime instead of a link error.

## Identity

```cpp
nosApplicationInfo appInfo{ .AppKey = "MyCorp-MyApp", .AppName = "My App" };
```

`AppName` is what the editor's **Apps** pane shows. `AppKey` identifies the application to the
engine.

## Two ways to use it

| | `NodosCommunicator` | `AppServiceClient` |
|---|---|---|
| You implement | `IApp` and `IAppNode` | `AppEventDelegates` |
| Events arrive | Inside your `PreExecute` call | As they land, on the SDK's thread |
| Frame synchronisation | Handled for you | Yours to build |
| Use when | Your application has a frame loop | You want the raw event stream |

Start with `NodosCommunicator`. Drop to `AppServiceClient` when you need something it does not
wrap — it is reachable through `GetClient()` either way.

### `NodosCommunicator`

Create it with your `IApp`, your loader, the engine address and your app info:

```cpp
auto communicator = nos::app::NodosCommunicator::Create(
    app, procLoader, "localhost:50053", appInfo);

if (auto* err = communicator.Error())
    return Fail(*err);
```

Then drive it from your own loop:

```cpp
if (communicator->PreExecute(frameCtx))   // true when the engine asked for this frame
    RenderForNodos();
else
    RenderNormally();

communicator->PostExecute(frameCtx);
```

| Method | Purpose |
|---|---|
| `PreExecute(void* frameCtx)` | Runs queued tasks, connects if not connected, and — when synced — waits for the engine's execution request. Returns whether the engine asked for this frame. Node callbacks are delivered here. |
| `PostExecute(void* frameCtx)` | Signals that the frame is complete. Does nothing if the matching `PreExecute` returned false. |
| `NotifyPinValueChanged(pinId, data, forceSendImmediately)` | Publish a new pin value. While synced this is deferred to the next `PostExecute` unless you force it. |
| `EnqueueTask(std::function<void()>)` | Run something on the next `PreExecute`. |
| `IsNodePresent()` | Whether your node currently exists in a graph. |
| `IsSynced()` | Whether the engine is driving your frames. |
| `GetClient()` | The underlying `AppServiceClient`. |

Its methods must be externally synchronised — drive it from one thread, or lock around it.

### `AppServiceClient`

`AppServiceClient::CreateClient(procLoader, serviceAddress, appInfo)` builds one directly. It owns
the client and shuts it down on destruction.

| Method | Purpose |
|---|---|
| `TryConnect()` | One connection attempt. Call it from a retry loop; it does not block until success. |
| `IsConnected()` | Current connection state. |
| `SetEventDelegates(AppEventDelegates&)` | Register your callbacks. |
| `ClearEventDelegates()` | Unregister them, before shutdown. |
| `Send(...)`, `SendPartialNodeUpdate(...)` | Send an app event, or a node update — this is how pins are added. |
| `NotifyPinValueChanged(...)`, `NotifyPinDirtied(...)` | Report a new pin value, or mark one dirty. |
| `SendPinShowAsChange(pinId, showAs)` | Promote or demote a pin. |
| `SendContextMenuUpdate(...)`, `UpdateStringList(...)` | Editor menus and string list pins. |
| `SendLog(message, detail, level)`, `SendWatchLog(key, message)` | Write to the editor's log and watch panes. |
| `DuplicateHandle(handle)`, `CloseHandle(handle)` | Share an OS handle with the engine process, and release it. |

Derive from `nos::app::AppEventDelegates` for the callbacks. Every method has a default
implementation, so override only the ones you care about.

## Callbacks

### `IApp`

| Callback | When |
|---|---|
| `CreateAppNode_ApiThread()` | Your application was placed in a graph. Return the node instance. Pure virtual. |
| `DestroyAppNode(IAppNode&)` | That instance is finished with. Pure virtual. |
| `OnConnected_ApiThread()` / `OnDisconnected_ApiThread()` | The connection came up, or went away. |
| `OnConsoleCommand(...)` / `OnConsoleAutoCompleteSuggestionRequest(...)` | Editor console input. |
| `OnCloseApp()` | The engine asks the application to exit. You may ignore it. |

### `IAppNode`

| Callback | When |
|---|---|
| `OnImport(nos::fb::Node const&)` | Your node was imported. Generally the first callback you see, and where you learn what pins it has. |
| `OnRemoved()` | The node was deleted from the graph. |
| `OnPinValueChanges(std::unordered_map<uuid, Buffer> const&)` | One or more pin values changed. |
| `OnPreExecute(void* frameCtx, uint64_t frameNumber)` | The engine requested this frame. |
| `OnPostExecute(void* frameCtx, uint64_t frameNumber)` | The frame was completed. |
| `OnSkippedExecution(void* frameCtx, SkippedExecutionInfo const&)` | A range of frames was skipped. |
| `OnExecutionStateChanged(newState, oldState)` | Execution state moved. An `_ApiThread` variant exists too. |
| `OnFunctionCall(...)` | A node function was called. |
| `OnPinShowAsChanged(pinId, showAs)` | A pin was promoted or demoted in the editor. |
| `OnNodeSelected(nodeId)`, `OnContextMenuRequested(...)`, `OnContextMenuCommandFired(...)` | Editor interaction. |
| `OnExecuteInfoChanged(...)`, `OnLoadNodesOnPaths(...)` | Scheduling information changed. |

!!! warning "Which thread a callback runs on"
    Anything whose name ends in `_ApiThread` runs on the SDK's own thread —
    `CreateAppNode_ApiThread`, `OnConnected_ApiThread`, `OnDisconnected_ApiThread` and
    `OnExecutionStateChanged_ApiThread`. Everything else is delivered inside your `PreExecute`
    call, on your thread, and needs no locking against your frame work.

## Connection

The engine's app service listens on `connection_settings/app_service_address`, `0.0.0.0:50053` by
default. Override per launch:

```shell
nosLauncher --override-settings connection_settings/app_service_address="0.0.0.0:50553"
```

See [Launcher CLI](../../using/reference/launcher-cli.md).

A client is bound to the address it was created with. To reach a different engine, destroy it and
create another.

## Samples

```shell
nodos get-sample vk_app   --output-dir ./samples
nodos get-sample dx12_app --output-dir ./samples
```

| Sample | Shows |
|---|---|
| `vk_app` | Vulkan application sharing textures with the engine. |
| `dx12_app` | DirectX 12 application. Nodos has no DX12 backend; this demonstrates cross-API texture sharing. |

Both follow the same shape: create a window and initialise the graphics API, wait for a connection,
add an input and an output pin, take the texture handle from the input pin, render onto it, present
it, and send the result back through the output pin.

An Unreal Engine 5 integration, *Nodos Link*, is maintained separately at
[github.com/mediaz/ue5plugin](https://github.com/mediaz/ue5plugin).

## Wire contracts

The app boundary is `AppService`, exchanging `AppEvent` and `EngineEvent` messages. The generated
FlatBuffers headers ship with the SDK:

```plaintext
AppEvents_generated.h
AppService_generated.h
Common_generated.h
```

## See also

- [Connect an external application](../how-to/connect-an-external-app.md)
- [Extension model](../explanation/extension-model.md) — when to use this instead of a plugin
- [Architecture](../../using/explanation/architecture.md)
