# Built-in data types

Pin data types are [FlatBuffers](https://flatbuffers.dev/) types. Nodos ships a set of built-ins on
top of the FlatBuffers scalars, defined in `Builtins.fbs` under the SDK's `Types/` directory.

Use the `type_name` values below in a [node definition](node-definition.md)'s `pins` array.

## Scalars

FlatBuffers' own scalar types map directly onto C++:

| `type_name` | C++ |
|:---|:---|
| `float` | `float` |
| `double` | `double` |
| `ubyte` | `uint8_t` |
| `ushort` | `uint16_t` |
| `uint` | `uint32_t` |
| `ulong` | `uint64_t` |
| `byte` | `int8_t` |
| `short` | `int16_t` |
| `int` | `int32_t` |
| `long` | `int64_t` |
| `bool` | `bool` |
| `string` | `const char*` — read with `GetPinValue<const char>` |
| `void` | `void` |

## Vectors

| `type_name` | Contents |
|:---|:---|
| `vec2` | `{float x, y;}` |
| `vec2d` | `{double x, y;}` |
| `vec2i` | `{int x, y;}` |
| `vec2u` | `{uint32_t x, y;}` |
| `vec3` | `{float x, y, z;}` |
| `vec3d` | `{double x, y, z;}` |
| `vec3i` | `{int x, y, z;}` |
| `vec3u` | `{uint32_t x, y, z;}` |
| `vec4` | `{float x, y, z, w;}` |
| `vec4d` | `{double x, y, z, w;}` |
| `vec4i` | `{int x, y, z, w;}` |
| `vec4u` | `{uint32_t x, y, z, w;}` |
| `vec4u8` | `{uint8_t x, y, z, w;}` |

## Matrices and transforms

| `type_name` | Contents |
|:---|:---|
| `mat2`, `mat3`, `mat4` | Float matrices. |
| `mat2d`, `mat3d`, `mat4d` | Double matrices. |
| `Transform` | `{vec3d position; vec3d rotation; vec3d scale;}` |

## Special types

`nos.exe`
:   **Execution pin.** Carries no value — it expresses that one node runs after another. A node
    reached by no execution path is never scheduled. See
    [Scheduling and execution](../../using/explanation/scheduling.md).

`nos.Generic`
:   **Template placeholder.** Resolves to a concrete type when the pin is connected or a value is
    entered. This is how one `Add` node serves integers, floats and vectors. Override
    `OnResolvePinDataTypes` to control resolution.

`nos.Any`
:   **Runtime-polymorphic reference.** Unlike `nos.Generic`, it does not resolve to a concrete
    type — the concrete type travels with the referenced object at runtime.

`nos.Dict`
:   **Dynamic dictionary.** Keys are chosen at runtime rather than declared in a schema, so
    arbitrarily typed values can be bundled without defining a dedicated type. Entries are
    `nos.DictEntry` — `{key, type_name, value}` — and the generic *Make* and *Break* reflection
    nodes understand it directly.

`nos.fb.StringList`
:   `{string name; vector<string> list;}`

## Module types

Modules contribute their own types, named after the module:

| `type_name` | Provided by |
|:---|:---|
| `nos.sys.vulkan.Texture` | `nos.sys.vulkan` |
| `nos.sys.vulkan.Buffer` | `nos.sys.vulkan` |
| `nos.audio.AudioPacket` | `nos.audio` |
| `nos.fb.NodeStatusMessageType` | Engine |
| `nos.reflect.BinaryOperator` | `nos.reflect` |

To see the types a module contributes, read its `Types/` directory or its generated headers under
`Include/<ModuleName>/`.

## Defining your own types

Put `.fbs` schemas in your plugin's `Types/` directory, or list paths under `custom_types` in the
[manifest](plugin-manifest.md). The toolchain runs `flatc` and generates headers into
`Include/<PluginName>/`.

Once generated, use the fully qualified FlatBuffers name as `type_name` in your node definitions.

## Reading pin values

```cpp
float          f   = *params.GetPinValue<float>(NSN_Gain);
uint32_t       n   = *params.GetPinValue<uint32_t>(NSN_Count);
nosVec2u       res = *params.GetPinValue<nosVec2u>(NSN_Resolution);
const char*    s   =  params.GetPinValue<const char>(NSN_Text);
auto           tex =  params.GetPinObject<nos::sys::vulkan::Texture>(NSN_Input);
```

Scalars and structs come back as pointers to dereference. Strings come back as `const char*`
already. Resources come back as object references via `GetPinObject`, never copied — see
[Objects and the type system](../explanation/objects-and-types.md).

## Full reference

The authoritative list is `Builtins.fbs` in the SDK:

```plaintext
Package/Downloaded/nodos.sdk.plugin/<version>/Types/Builtins.fbs
```

The same schemas also ship inside each engine install, under `Engine/<version>/SDK/Plugin/Types/`.
Many further types are built on these with enums; reading the schema directly is the quickest way
to find one.
