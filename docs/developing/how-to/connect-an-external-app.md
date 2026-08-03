# Connect an external application

An application that links the Nodos **Application SDK** connects to a running engine over gRPC and
appears in the graph as a node. From then on it can be wired to other nodes, and its pins can be
driven from the editor.

One process gets one node. The application can modify that node — add pins, change values — but it
cannot create additional nodes.

This is the right integration when the code cannot live inside the engine process: an existing
renderer, a different graphics API, a separate release cycle. If your code *can* live in-process,
[write a plugin](../tutorials/your-first-plugin.md) instead — it is simpler and faster.

## 1. Check SDK compatibility

The Application SDK versions independently of the engine. Before anything else, make your build
system check the version and locate the SDK:

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

Every header you need is under `include/` in the directory printed above. Add it to your include
path.

The headers require {{ cpp_version }}, so your project must target at least that.

## 3. Load the dynamic library

`nosAppSDK` is loaded at runtime, not linked. Load it with your platform's dynamic loading API and
resolve three functions, casting each to its declared type:

| Symbol | Cast to |
|---|---|
| `CheckSDKCompatibility` | `nos::app::FN_CheckSDKCompatibility*` |
| `MakeAppServiceClient` | `nos::app::FN_MakeAppServiceClient*` |
| `ShutdownClient` | `nos::app::FN_ShutdownClient*` |

`CheckSDKCompatibility`
:   Call first, with the version your headers declare. Fails if the headers disagree with the
    library the binary actually loaded. This catches the mismatch that would otherwise show up as
    memory corruption much later.

`MakeAppServiceClient`
:   Creates an `AppServiceClient` for a given address. This is your handle on the gRPC connection
    and the object you register callbacks with.

`ShutdownClient`
:   Releases everything associated with a client. Call it after unregistering delegates, on
    disconnect or shutdown.

## 4. Implement the event delegates

Communication is asynchronous and callback-driven. There is no polling API, so implementing the
delegates is not optional — it is the only way the engine talks to you.

1. Derive from `nos::app::IEventDelegates`.
2. Implement every pure virtual function.
3. Pass an instance to `client->RegisterEventDelegates()`.

The SDK holds the object and forwards it to the engine over gRPC when you connect.

!!! warning "Callbacks arrive on a different thread"
    Event callbacks do not run on your main thread. Push incoming events onto a queue keyed by the
    `FrameNumber` you are given, and drain it from your own loop. Handling them inline is the most
    common source of synchronisation bugs in app integrations.

## 5. Connect

The address and port were fixed when you called `MakeAppServiceClient`, so start an engine
listening there:

```shell
nodos launch
```

Then:

```cpp
if (!client->IsConnected())
    client->TryConnect();
```

`TryConnect` is a single attempt, so call it from a retry loop rather than expecting it to block
until success.

!!! info "Connecting somewhere else"
    An `AppServiceClient` is bound to the address it was created with. To connect to a different
    engine, destroy the client and create a new one.

The engine's app service listens on `app_service_address`, `0.0.0.0:50053` by default. Override it
per launch:

```shell
nosLauncher --override-settings connection_settings/app_service_address="0.0.0.0:50553"
```

## 6. Use the node

Your application's name — the one you passed to `MakeAppServiceClient` — appears in the **Apps**
pane of the editor. Drag it into the node graph, and `onNodeUpdated()` fires.

From there, add pins to your node and read and write their values through the client. Wire the node
to the rest of the graph like any other.

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
