# Objects and the type system

Two decisions shape how data moves through a Nodos graph: pin data is FlatBuffers, and resources are
reference-counted objects rather than values. Both are worth understanding, because both show up in
the API in ways that are otherwise puzzling.

## Why FlatBuffers

Nodos has to describe the same node to four audiences: the engine executing it, an editor drawing
it, a plugin implementing it, and possibly an application in another process driving it. Those are
different binaries, built at different times, in different languages potentially.

FlatBuffers gives one schema definition that produces the wire contract, the serialisation code and
the SDK headers. The engine, the editor and a plugin cannot disagree about what a node is, because
they are all generated from the same `.fbs`.

It also reads without parsing. Pin values are accessed in place rather than deserialised into
intermediate structures, which matters when you are doing it per pin, per node, per frame.

The practical consequence for plugin authors: your pin types are FlatBuffers types. Custom types go
in `.fbs` files under `Types/`, `flatc` generates headers into `Include/<PluginName>/`, and the
generated name is what you put in `type_name`. See
[Built-in data types](../reference/builtin-types.md).

## Generic, Any, and Dict

Three built-in types exist for cases where the schema cannot be fixed in advance, and they are
genuinely different things.

`nos.Generic`
:   A **template placeholder**. It resolves to a concrete type when the pin is connected or a value
    entered, and after that it is that type. This is how one `Add` node class serves integers,
    floats and vectors — the class is generic, each instance is not. Override
    `OnResolvePinDataTypes` to influence resolution.

`nos.Any`
:   **Runtime-polymorphic**. It does not resolve; the concrete type travels with the referenced
    object. Use it when the type genuinely is not known until execution.

`nos.Dict`
:   A **dynamic dictionary** whose keys are chosen at runtime rather than declared in a schema.
    Entries are `{key, type_name, value}`, and because a Dict is itself reached through a dynamic
    pin, dynamic types nest inside dynamic types. The generic *Make* and *Break* reflection nodes
    handle it directly.

Reach for `nos.Generic` first. It is the one that keeps type errors at connection time rather than
execution time.

## Objects, not values

A texture is not copied into your node. Nothing large is.

The engine owns runtime objects. Pins reference them; your node gets a counted reference. This is
the only workable arrangement for a real-time GPU pipeline — copying a 4K texture between nodes at
60 FPS is not an option — but it means resource lifetime is something you participate in rather
than something you can ignore.

### Object kinds

Objects fall into four kinds, distinguished by how their data is held:

**Primitive** — a buffer-backed value.

**Foreign** — owned by a plugin rather than the engine. The plugin's `Construct` allocates and
returns a handle plus serialised data, and its `Release` is called when the last reference goes.
GPU resources are foreign objects, which is why `nos.sys.vulkan` is the thing that frees a texture,
not the engine.

**Composite** — a structure whose fields are themselves object references.

**Array** — a sequence whose elements are object references.

You mostly do not need to care which you are holding — `ObjectRef` behaves the same either way. It
matters when you implement a custom object type, because that is when you supply the `Construct`
and `Release` that make yours foreign.

### References

`ObjectRef` is RAII. Creating one takes a reference on the object; destroying one releases it. When
the last reference goes, the object is destroyed — and for a foreign object, the owning plugin's
`Release` is called.

```cpp
auto tex = args.GetPinObject<vkss::Texture>(NSN_Output);   // a reference
auto info = vkss::GetResourceInfo(tex);                     // nullopt if the pin has none

if (!info || info->Width != wanted)
{
    tex = vkss::CreateTexture(desc, "Output");              // old reference released here
    SetPinObject(NSN_Output, tex);                          // publish the new one
}
```

There is no destroy call in that snippet, and that is the point. The old texture is released when
the last reference to it goes out of scope.

This is why the SDK gives you `nos::ObjectRef` and `nos::TypedObjectRef` rather than leaving you
with raw `nosObjectId` values and C resource structs. Manual reference counting across early
returns and exception paths leaks, reliably, in proportion to how much code you write.

Taking and releasing references is safe from any runner thread, and is designed not to become a
contention point when many nodes do it concurrently. You do not need to add locking of your own
around an `ObjectRef`.

## What this means in practice

**Never hold a raw handle across frames.** Hold an `ObjectRef`. A raw id can outlive the object it
names.

**Check `GetResourceInfo` for `nullopt`.** A pin that has not been given a resource yet returns
nothing, which conveniently collapses the "create it" and "resize it" cases into one branch.

**Publishing is explicit.** Creating a new resource does not put it on the pin; `SetPinObject`
does.

**Foreign object lifetime crosses the plugin boundary.** Your `Release` is called by the engine when
the reference count hits zero, on whichever thread dropped the last reference.

## See also

- [Built-in data types](../reference/builtin-types.md)
- [Plugin API](../reference/plugin-api.md)
- [`nos.sys.vulkan`](../reference/subsystems/nos.sys.vulkan.md)
