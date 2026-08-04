# Plugin API (C++)

The plugin SDK is a C API (`Nodos/PluginAPI.h`) with C++ helpers layered on top
(`Nodos/Plugin.hpp`). Write against the helpers; the C layer is the ABI boundary, not the authoring
surface.

Describes plugin SDK {{ plugin_sdk_version }} (Nodos {{ nodos_version }}).

```cpp
#include <Nodos/Plugin.hpp>   // pulls in PluginAPI.h and the C++ helpers
```

## Entry point

`PluginMain.inl` generates the plugin entry point from two macro lists.

```cpp title="Source/PluginMain.cpp"
#include <Nodos/Plugin.hpp>
#include <mycorpMyplugin/mycorpMyplugin.h>

#define NOS_NODES        \
    NOS_NODE(NodeA)      \
    NOS_NODE(NodeB)

#define NOS_DEPENDENCIES     \
    NOS_DEPENDENCY(NOS_VULKAN)

#define NOS_NAMESPACE mycorp::myplugin

#include <Nodos/PluginMain.inl>
```

`NOS_NODES`
:   One `NOS_NODE(X)` per node class. Each requires a matching
    `nosResult RegisterX(nosNodeFunctions*)` in the `NOS_NAMESPACE` namespace. The include
    generates the declarations, the node enum, and the `ExportNodeFunctions` implementation.

`NOS_DEPENDENCIES`
:   One `NOS_DEPENDENCY(X)` per dependency, where `X` is the prefix of the dependency's
    `X_INIT()` / `X_IMPORT()` macro pair. Expanded into both an init and an import.

`NOS_NAMESPACE`
:   Required. The namespace holding your node classes and registration functions.

`NOS_PLUGIN_FUNCTIONS_NAME`
:   Optional. Define it, and declare a struct of that name deriving from `nos::PluginFunctions`, to
    override plugin-level callbacks. Otherwise a struct is generated.

### Doing it by hand

Equivalent, and still supported:

```cpp
NOS_INIT()
NOS_VULKAN_INIT()

NOS_BEGIN_IMPORT_DEPS()
    NOS_VULKAN_IMPORT()
NOS_END_IMPORT_DEPS()

struct MyPluginFunctions : nos::PluginFunctions
{
    nosResult ExportNodeFunctions(size_t& outSize, nosNodeFunctions** outFunctions) override;
};

NOS_EXPORT_PLUGIN_FUNCTIONS(MyPluginFunctions);
```

`ExportNodeFunctions` is called twice: once with `outFunctions == nullptr` to ask how many node
classes there are, then again to fill the list. Set `outSize` and return early on the first call.

## `PluginFunctions`

Plugin-level callbacks.

| Method | Purpose |
|---|---|
| `ExportNodeFunctions(size_t& outSize, nosNodeFunctions** outFunctions)` | Report and register node classes. |
| `Initialize()` | Called after the plugin loads and its static components are registered. |
| `OnPreUnloadPlugin()` | Called before unload. Release anything the engine must not outlive. |

## Registering a node class

```cpp
nosResult RegisterPrintFloat(nosNodeFunctions* fn)
{
    NOS_BIND_NODE_CLASS(NOS_NAME("mycorp.myplugin.PrintFloat"), PrintFloat, fn);
    return NOS_RESULT_SUCCESS;
}
```

`NOS_BIND_NODE_CLASS(Name, ContextClass, Functions)`
:   Wires every callback on `nosNodeFunctions` to the corresponding virtual on your context class,
    including construction, destruction, and the node function table. There is nothing to hook up
    manually.

`NOS_REGISTER_NODE(NodeName)`
:   Shorthand that defines `RegisterNodeName` for you, binding `NOS_NAME(#NodeName)` to the class
    and calling its static `OnRegister`.

The name must match the `class_name` in the [node definition](node-definition.md), fully qualified.

## `NodeContext`

One instance per node in the graph. Override the callbacks you need; all have no-op defaults. The
tables below are the surface; [Node lifecycle and callbacks](node-lifecycle.md) is the order the
engine calls them in and the thread it calls them on.

```cpp
struct PrintFloat : nos::NodeContext
{
    using nos::NodeContext::NodeContext;

    nosResult ExecuteNode(nos::NodeExecuteParams const& params) override
    {
        float v = *params.GetPinValue<float>(NOS_NAME("Message"));
        nosEngine.LogI("value: %f", v);
        return NOS_RESULT_SUCCESS;
    }
};
```

### Members

| Member | Type |
|---|---|
| `NodeId` | `uuid` — this node's id. Pass it to `BeginCmd` and similar. |
| `NodeName` | `nos::Name` |
| `NodeDisplayName` | `std::optional<std::string>` |
| `PinName2Id` | `std::unordered_map<Name, uuid>` |
| `Pins` | `std::unordered_map<uuid, NodePin>` |

### Lifecycle

| Callback | When |
|---|---|
| `nosResult OnCreate(nosFbNodePtr node)` | Node created. |
| `nosResult OnDestroy()` | Node deleted, before destruction. |
| `static nosResult OnRegister(nosNodeFunctions&)` | Class registered, once per plugin load. |

### Execution

| Callback | When |
|---|---|
| `nosResult ExecuteNode(NodeExecuteParams const&)` | The scheduler runs this node. |
| `nosResult CopyFrom(nosCopyFromInfo*)` | Copy semantics for this node. |
| `void OnBeginFrame(uuid const& pinId)` | Frame begins on a path this node is in. |
| `void OnEndFrame(uuid const& pinId, nosEndFrameCause cause)` | Frame ends. |
| `void OnPathStart()` | Path started. |
| `void OnPathStartInitiated()` | Path start initiated. |
| `void OnPathStop()` | Path stopped. |
| `void OnPathStateChanged(nosPathState)` | Path state transition. |
| `void OnPathCommand(const nosPathCommand*)` | Path command received. |
| `void OnEnterRunnerThread(...)` / `OnExitRunnerThread(...)` | Node migrates between runner threads. |
| `void GetScheduleInfo(nosScheduleInfo*)` | Report scheduling requirements. |
| `void OverrideConsumerDeltaSeconds(nosVec2u&)` | Override the consumer frame interval. |

!!! warning
    `ExecuteNode` is called because the scheduler decided the node is due, not because a value
    changed. To react to a value changing, override `OnPinValueChanged`.

### Pins

| Callback | When |
|---|---|
| `void OnPinValueChanged(nos::Name, uuid const&, nosBuffer)` | A pin's value changed. |
| `void OnPinObjectChanged(nos::Name, uuid const&, nosObjectId)` | A pin's object reference changed. |
| `void OnPinConnected(nos::Name, uuid const&, nosObjectId)` | A pin was connected. |
| `void OnPinDisconnected(nos::Name)` | A pin was disconnected. |
| `void OnPinUpdated(const nosPinUpdate*)` | A pin was updated. |
| `void OnPinDirtied(uuid const&, uint64_t frameCount)` | A pin was dirtied. |
| `nosResult CanRemoveOrphanPin(nos::Name, uuid const&)` | Veto removal of an orphan pin. |
| `nosResult OnResolvePinDataTypes(nosResolvePinDataTypesParams*)` | Resolve `nos.Generic` pin types. |

### Node and editor

| Callback | When |
|---|---|
| `void OnNodeUpdated(const nosNodeUpdate*)` | Node updated. |
| `void OnFunctionUpdated(const nosNodeFunctionUpdate*)` | A node function was updated. |
| `void OnMenuRequested(nosContextMenuRequestPtr)` | Context menu requested. |
| `void OnNodeMenuRequested(nosContextMenuRequestPtr)` | Node context menu requested. |
| `void OnPinMenuRequested(nos::Name, nosContextMenuRequestPtr)` | Pin context menu requested. |
| `void OnMenuCommand(uuid const&, uint32_t cmd)` | A menu item was chosen. |
| `void OnKeyEvent(const nosKeyEvent*)` | Key event. |
| `nosResult OnCustomMessageReceived(nosNodeMessageParams const*)` | Custom message from an editor. |

### Helpers on `NodeContext`

`SetPinValue(nos::Name, T)`
:   Write a pin value. Writing to an *input* pin dirties the node and re-triggers `ExecuteNode`,
    which is why a callable function that writes a pin rarely needs `always_execute`.

`SetPinObject(nos::Name, ObjectRef)`
:   Publish a new object reference on a pin, e.g. after reallocating a texture.

`SetNodeStatusMessage(std::string, nos::fb::NodeStatusMessageType)`
:   Set the status shown on the node. Types include `INFO`, `WARNING`, `FAILURE`.

## `NodeExecuteParams`

Passed to `ExecuteNode`. It is an `unordered_map<Name, nosPinInfo>` with accessors:

`GetPinValue<T>(nos::Name)`
:   Returns `const T*` for pointer-like types, `T` otherwise. Dereference for scalars:

    ```cpp
    float f      = *params.GetPinValue<float>(NSN_Gain);
    const char* s = params.GetPinValue<const char>(NSN_Text);
    auto res     = *params.GetPinValue<nosVec2u>(NSN_Resolution);
    ```

`GetPinObject<T>(nos::Name)`
:   Returns a `TypedObjectRef<T>` — a counted reference to an engine-owned resource. This is how
    textures and buffers arrive.

`GetPinBuffer(nos::Name)`
:   Returns the raw `nosImmutableBuffer` for the pin.

It also carries `NodeClassName`, `NodeName`, `NodeId`, `FrameNumber`, `MarkAllOutsDirty` and
execution timing.

### Pin name constants

Declare name constants once rather than constructing them per frame:

```cpp
NOS_REGISTER_NAME(Gain)       // defines NSN_Gain
NOS_REGISTER_NAME(Resolution) // defines NSN_Resolution
```

`NOS_NAME("...")` works inline; `NOS_NAME_STATIC("...")` is the static form.

## Node functions

Node functions are the callable buttons on a node. Declare them in the
[node definition's `functions` array](node-definition.md), implement them as members taking
`nosFunctionExecuteParams*`, and list them with `NOS_DECLARE_FUNCTIONS`:

```cpp
struct CounterNode : nos::NodeContext
{
    int32_t Counter = 0;

    void SetCount(int32_t value)
    {
        Counter = value;
        SetPinValue(NSN_Count, Counter);
    }

    nosResult ExecuteNode(nos::NodeExecuteParams const& execParams) override
    {
        int32_t step = *execParams.GetPinValue<int32_t>(NSN_Step);
        SetCount(Counter + step);
        return NOS_RESULT_SUCCESS;
    }

    nosResult Reset(nosFunctionExecuteParams*)
    {
        SetCount(0);
        return NOS_RESULT_SUCCESS;
    }

    NOS_DECLARE_FUNCTIONS(
        NOS_ADD_FUNCTION(NOS_NAME("Reset"), Reset),
    );
};
```

`NOS_BIND_NODE_CLASS` picks the declaration up automatically. If you need full control, define a
static `GetFunctions(size_t* outCount, nosName* outNames, nosPfnNodeFunctionExecute* outFns)`
instead and it will be used.

## Engine services

`nosEngine` is the global service table, available once dependencies are imported.

### Logging

```cpp
nosEngine.LogI("info %d", x);
nosEngine.LogW("warning");
nosEngine.LogE("error");
nosEngine.LogD("debug");
```

Output goes to the editor's **Log** pane and to the engine log files. These are printf-style, so
format specifiers must match.

### Subsystems

```cpp
nosVulkanSubsystem* nosVulkan = nullptr;
auto ret = nosEngine.RequestSubsystem(
    NOS_NAME_STATIC(NOS_VULKAN_SUBSYSTEM_NAME), 8, 0, (void**)&nosVulkan);
if (ret != NOS_RESULT_SUCCESS)
    return ret;
```

Always check the result — the requested version may not be installed. On {{ nodos_version }},
prefer declaring the dependency and letting `NOS_DEPENDENCIES` import it.

## Conventions

- C++ constants are `SCREAMING_SNAKE_CASE`, not `kCamelCase`.
- Use `nos::ObjectRef` / `nos::TypedObjectRef` rather than raw `nosObjectId` or C resource structs.
- Bump the major version in your manifest on any API break; leave dependency versions alone unless
  that is the change you are making.

## See also

- [Node lifecycle and callbacks](node-lifecycle.md)
- [Node definition](node-definition.md)
- [`nos.sys.vulkan`](subsystems/nos.sys.vulkan.md)
- [Objects and the type system](../explanation/objects-and-types.md)
