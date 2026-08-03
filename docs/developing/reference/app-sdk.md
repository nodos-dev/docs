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
usable directly as a build-system check. Headers are under `include/` in the reported directory.

The engine's own value is `process_sdk_version` in `Engine/<version>/SDK/info.json`.

Headers require {{ cpp_version }}.

## Entry points

Load the `nosAppSDK` shared library with your platform's dynamic loading API — `GetProcAddress` on
Windows, `dlsym` elsewhere — and resolve these, casting each to its declared function type:

| Symbol | Function type | Purpose |
|---|---|---|
| `CheckSDKCompatibility` | `nos::app::FN_CheckSDKCompatibility*` | Verify header/library agreement. |
| `MakeAppServiceClient` | `nos::app::FN_MakeAppServiceClient*` | Create a client for an address. |
| `ShutdownClient` | `nos::app::FN_ShutdownClient*` | Release a client and its resources. |

### `CheckSDKCompatibility`

```cpp
nosBool CheckSDKCompatibility(int major, int minor, int patch);
```

Call first, passing the version your headers declare. Returns false when the loaded library was
built against an incompatible version. Checking here turns a silent ABI mismatch into an
actionable startup error.

### `MakeAppServiceClient`

```cpp
nosAppServiceClient* MakeAppServiceClient(const char* serviceAddress, /* ... */);
```

Creates a client bound to one engine address. The name you supply is what appears in the editor's
**Apps** pane.

A client is bound to the address it was created with. To connect elsewhere, destroy it and make a
new one.

### `ShutdownClient`

```cpp
void ShutdownClient(nosAppServiceClient* client);
```

Releases everything associated with the client. Unregister delegates first.

## `AppServiceClient`

| Method | Purpose |
|---|---|
| `IsConnected()` | Whether the client is currently connected. |
| `TryConnect()` | Attempt a connection. A single attempt — call it from a retry loop. |
| `RegisterEventDelegates(...)` | Register your `IEventDelegates` implementation. |

## `IEventDelegates`

The engine communicates with your application exclusively through callbacks. There is no polling
API, so implementing these is not optional.

1. Derive from `nos::app::IEventDelegates`.
2. Implement every pure virtual.
3. Pass an instance to `RegisterEventDelegates`.

The SDK holds the object and forwards it to the engine over gRPC on connection.

`onNodeUpdated()` fires when your application node is placed in the graph or changes, and is
generally the first callback you will see.

!!! warning "Threading"
    Callbacks run on a thread other than your main thread. Queue incoming events keyed by the
    `FrameNumber` you are given, and drain the queue from your own loop. Handling them inline is the
    most common source of synchronisation bugs in app integrations.

## Connection

The engine's app service listens on `connection_settings/app_service_address`, `0.0.0.0:50053` by
default. Override per launch:

```shell
nosLauncher --override-settings connection_settings/app_service_address="0.0.0.0:50553"
```

See [Launcher CLI](../../using/reference/launcher-cli.md).

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
ProcessNode_generated.h
Common_generated.h
```

## See also

- [Connect an external application](../how-to/connect-an-external-app.md)
- [Extension model](../explanation/extension-model.md) — when to use this instead of a plugin
- [Architecture](../../using/explanation/architecture.md)
