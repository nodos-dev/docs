# Generics

Nodos is a very large developing platform, so we use several 3rd-party libraries and built some standards on top of them. These are important for developers that'll use C/C++ APIs of Nodos.

## Flatbuffers

Our cross-process communication is based on Google's [gRPC](https://grpc.io/) and [flatbuffers](https://flatbuffers.dev/). We represent nodes, pins and their data types with flatbuffers. So you should use flatbuffers to create your own data types. For this purpose, you're gonna use built-in flatbuffers types.

#### Built-in data types
Flatbuffers already has built-in types (such as `float`, `uint` etc), but we define the types below on top of them because they're used frequently by developers:

| flatbuffers type | C++ type |
|:----------:|:----------:|
|float|float|
|double|double|
|ubyte|uint8_t|
|ushort|uint16_t|
|uint|uint32_t|
|ulong|uint64_t|
|byte|int8_t|
|short|int16_t|
|int|int32_t|
|long|int64_t|
|vec2|`{float x,y;}`|
|vec2d|`{double x,y;}`|
|vec2i|`{int x,y;}`|
|vec2u|`{uint32_t x,y;}`|
|vec3|`{float x,y,z;}`|
|vec3d|`{double x,y,z;}`|
|vec3i|`{int x,y,z;}`|
|vec3u|`{uint32_t x,y,z;}`|
|vec4|`{float x,y,z,w;}`|
|vec4d|`{double x,y,z,w;}`|
|vec4i|`{int x,y,z,w;}`|
|vec4u|`{uint32_t x,y,z,w;}`|
|vec4u8|`{uint8_t x,y,z,w;}`|
|void|void|
|StringList|`{string name; vector<string> list;}`|

There are many more built-in types but they're mostly built on top these with some enums so we recommend you to investigate it yourself in `SDK/types/Builtins.fbs` file.