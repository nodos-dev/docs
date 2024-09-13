# Plugins

A Nodos plugin defines nodes and their behaviors, and pin data types. Nodos loads plugins dynamically and makes its nodes and data types available to be used in the node graph to perform tasks.

Nodos Package Manager CLI tool (`nodos`) has a command `create plugin` that can generate a simple plugin for Nodos. You can use `nodos create --help` for detailed information about the command.

#### Create a plugin
Let's create our first Nodos plugin with command below.

```shell
nodos create plugin mycorp.myplugin
```

It will output:
```plaintext
Creating a new Nodos module project of type Plugin
Plugin project created at "./Module/mycorp.myplugin"
Found 1 modules in C:/Nodos/Module/mycorp.myplugin
```

This will create a folder named `mycorp.myplugin` under `Module` folder of **Nodos Workspace** (where `nodos` tool resides) with folder structure as below.

```plaintext
./Module/mycorp.myplugin/
├── CMakeLists.txt
├── Source
│   └── PluginMain.cpp
└── mycorp.myplugin.noscfg
```

This folder contains a CMake project file, a C++ source file with minimal code and a Nodos plugin manifest file `.noscfg`.

#### Building
Now generate CMake project using our CMake helpers, which can be found in `Toolchain/CMake` folder of Nodos Workspace and build it using commands run from workspace root:

```shell
# This will scan 'Module' folder and generate project files.
cmake -S Toolchain/CMake -B Project
```

```shell
cmake --build Project
```

This will result in a DLL file under `Module/mycorp.myplugin/Binaries` folder, and Nodos will be able to load this plugin.

#### Loading a plugin
Open the editor and click **Fetch** button of **Modules** pane. This will scan the plugin and show it under uncategorized table on **Plugins** section. Click on the plugin and you'll see **Load** button at the bottom. 

!!! info
    A plugin should implement `nosImportDependencies`, `nosExportPlugin` & `nosGetPluginAPIVersion` functions in Nodos C API for plugins (defined under `Engine/<version>/SDK/include/PluginAPI.h`).

#### Defining a node

For simplicity, tutorial will be based on our C++ helpers. Create a struct `PluginExtension` that is derived from nos::PluginFunctions publicly and override `ExportNodeFunctions()` function.

When a plugin is loaded, `ExportNodeFunctions()` is called twice by the engine. One for querying node count and another one for getting the node list. That means, your function should start something like,

```cpp
*outSize = nodeSize;
if(!outFunctions) 
    return NOS_RESULT_SUCCESS;
```
and then start filling **`nosNodeFunctions*`** list.

For each node you want to register, you can implement a class derived from **`nos::NodeContext`**. You should override the base class' functions you're going to use (`OnPinValueChanged()` for example).

<details>

<summary>Example C++ code</summary>

Registering a node that gets float from input pin and prints it on Log pane
```cpp
#include <Nodos/PluginAPI.h>
#include <Nodos/PluginHelpers.hpp>
#include <Nodos/Helpers.hpp>

NOS_INIT() // Defines nosGetPluginAPIVersion
NOS_BEGIN_IMPORT_DEPS() // Defines nosImportDependencies and makes nosEngineServices available as 'nosEngine'.
    // If you have dependencies, you can define them here like
    // NOS_IMPORT_DEP("mycorp.somedep", "1.0.0"...)
NOS_END_IMPORT_DEPS()

struct PrintLogPaneNodeContext : nos::NodeContext
{
    PrintLogPaneNodeContext(const nosFbNode* node) : nos::NodeContext(node)
    {
    }

    void OnPinValueChanged(nos::Name pinName, nosUUID pinId, nosBuffer value) override
    {
        if (pinName == NOS_NAME_STATIC("Message"))
        {
            auto* floatInfo = nos::InterpretPinValue<float>(value);
            nosEngine.LogI(std::to_string(*floatInfo).c_str());
        }
    }
};

nosResult RegisterPrintLogPaneNode(nosNodeFunctions* outFunctions)
{
    NOS_BIND_NODE_CLASS(NOS_NAME("mycorp.myplugin.PrintLog"), 
        PrintLogPaneNodeContext, 
        outFunctions)
    return NOS_RESULT_SUCCESS;
}

struct PluginExtension : public nos::PluginFunctions
{
    virtual nosResult ExportNodeFunctions(size_t& outSize, nosNodeFunctions** outFunctions) override
    {
        outSize = 1;
        if (!outFunctions)
            return NOS_RESULT_SUCCESS;

        NOS_RETURN_ON_FAILURE(RegisterPrintLogPaneNode(outFunctions[0]));
        return NOS_RESULT_SUCCESS;
    }
};

NOS_EXPORT_PLUGIN_FUNCTIONS(PluginExtension);
```

</details>

If you build the plugin and try to load it from the engine, you'll get ***"Plugin is trying to register a node that doesn't exist in its node definitions"*** error. This is because Nodos reads node configuration (**.noscfg**) and node definition (**.nosdef**) files to create node properties.

Configuration file describes the whole plugin such as; compiled binary path, node definition file paths, plugin's dependencies to subsystems and other plugins, custom data types ([flatbuffers](https://flatbuffers.dev/) based).

To add a node, create a **.nosdef** file. It should have JSON schema. You can define multiple nodes in one **.nosdef** file.

Each node should have a class name, display name, content type (either a job that has no sub-nodes or a graph that has sub-graphs), user-friendly description text, pins & functions.

We're gonna use only a single pin today, so we don't need to define functions. After describing your nodes in the related **.nosdef** files, you should associate them with the plugin in **.noscfg**'s `associated_nodes` list.


<details>
<summary>Example .noscfg & .nosdef files</summary>

Registering a node that gets float from input pin and prints it on <b>Log pane</b>
<details>
<summary>.nosdef</summary>
```json
{
    "nodes":[
        {
            "class_name": "PrintLog",
            "display_name": "Test to Log",
            "contents_type": "Job",
            "description": "Prints the inputted float into log",
            "pins": [
                {
                    "name": "Message",
                    "type_name": "float",
                    "show_as": "INPUT_PIN",
                    "can_show_as": "INPUT_PIN_ONLY"
                }
            ]
        }
    ]
}
```
</details>

<details>
<summary>.noscfg</summary>
```json
{
    "info": {
        "id": {
            "name": "mycorp.myplugin",
            "version": "0.1.0"
        },
        "display_name": "mycorp.myplugin",
        "description": "",
        "dependencies": []
    },
    "binary_path": "./Binaries/mycorp.myplugin",
    "node_definitions": [
        "PrintLog.nosdef"
    ],
    "defaults": [],
    "custom_types": [],
    "associated_nodes": [
        {
            "category": "Sample",
            "class_name": "PrintLog",
            "display_name": "Print Log"
        }
    ]
}
```
</details>

</details>

Now you should be able to see your first node in the node graph. In examples above, we created a node that prints to **Log pane** only if the pin's value changes. So create an **Add** node and sets its input values. After you connect it to the Message pin, `OnPinValueChanged()` will be called and it will print the value. Everytime you change the pin's value by changing output value of the connection, it'll be printed.

##### Using nodos CLI to add a pin
You can use `nodos pin` command to add a pin to a node in the workspace. If not all parameters are provided, it will enter interactive mode.

```shell
nodos pin mycorp.myplugin.PrintLog SomeNewPin
```
Because we didn't provide `--show-as` parameter, it will ask for it. This is used to define the pin's current kind in the node. It can be an input pin, output pin or a property.

```plaintext
? Select pin show-as:
> INPUT_PIN
  OUTPUT_PIN
  PROPERTY
[↑↓ to move, enter to select, type to filter]
```

After this, it will ask for the `can-show-as` parameter. This is used to define which show-as options are available for the pin.

```plaintext
? Select pin can-show-as:
  [x] INPUT_PIN
  [ ] OUTPUT_PIN
> [x] PROPERTY
[↑↓ to move, space to select one, → to all, ← to none, type to filter]
```
Here we selected `INPUT_PIN` and `PROPERTY` as the options. You can select multiple options by pressing space.
This creates the possibility for this pin to be changed to a property in the editor by the end user.

After this, it will ask for the `type-name` parameter. This parameter is used to define the data type of the pin.

```plaintext
? Enter pin type name for pin: float
```

You can use `nodos pin --help` for detailed information about the command.
