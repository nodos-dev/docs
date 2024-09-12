# Plugins

nodos has a command-line interface argument `create plugin` that can generate a simple test plugin. You can use `nodos create --help` for syntax.

#### Create a plugin
Let's create our first plugin with command below. This command will generate `firstexample` folder in `Module` folder.

`nodos create plugin firstexample`

!!! info
    Programmers that are experienced in the subject can investigate it for further details (about our build system helpers, include directories etc.). This page is only dedicated for programmers that're not familiar with the subject. For more info on the API itself, visit [Plugins](../plugins/index.md) & [Subsystems](../subsystems/index.md)

!!! info
    Plugin names shouldn't have any upper-case letter. It should only have lower-case letters and numbers.

#### Build plugin
Now generate CMake project using our toolchain (can be found in `Toolchain/CMake` folder of nodos' location) and build it. You'll see `thirdex.dll` file in `Binaries` subfolder.

!!! info
    If you created the plugin under `Module` folder, you can run the command below in plugin's folder to generate the CMake project.

    `cmake -S ../../Toolchain/CMake -B Project`

#### Load plugin into Editor
Open the editor and click **Fetch** button of **Modules** pane. This will load the plugin and show it under uncategorized table on **Plugins** section. Click on the plugin and you'll see **Load** button at the bottom. If you click it, it'll fail to load (can be seen in **Log** pane).

The reason is that a plugin should implement `nosExportPlugin()` function and it's not in our plugin right now. Let's implement them.

!!! info
    A plugin should implement `nosImportDependencies()` and `nosExportNodeFunctions()` but they're already implemented in our template plugin

#### Comfort implementation requirements
For simplicity, tutorial will be based on our C++ helpers. Create a struct `PluginExtension` that is derived from nos::PluginFunctions publicly and override `ExportNodeFunctions()` function.

When a plugin is loaded, `ExportNodeFunctions()` is called twice by the engine. One for querying node count and another one for getting the node list. That means, your function should start something like `outSize = nodeSize; if(!outFunctions){return NOS_RESULT_SUCCESS;}` and then start filling **`nosNodeFunctions*`** list.

For each node you want to register, you can implement a struct derived from **`nos::NodeContext`**. You gotta override the base class' functions you're gonna use (`OnPinValueChanged()` for example).

<details>

<summary>Example C++ code</summary>

Registering a node that gets float from input pin and prints it on Log pane
```cpp
#include <Nodos/PluginAPI.h>
#include <Nodos/PluginHelpers.hpp>
#include <Nodos/Helpers.hpp>

NOS_INIT();
NOS_BEGIN_IMPORT_DEPS()
NOS_END_IMPORT_DEPS()

struct PrintOnLogPaneNodeContext : nos::NodeContext
{
    PrintOnLogPaneNodeContext(const nosFbNode* node) : nos::NodeContext(node)
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

nosResult RegisterPrintOnLogPaneNode(nosNodeFunctions* outFunctions)
{
    NOS_BIND_NODE_CLASS(NOS_NAME_STATIC("thirdex.PrintOnLog"), PrintOnLogPaneNodeContext, outFunctions)
        return NOS_RESULT_SUCCESS;
}

struct PluginExtension : public nos::PluginFunctions
{
    virtual nosResult ExportNodeFunctions(size_t& outSize, nosNodeFunctions** outFunctions) override
    {
        outSize = 1;
        if (!outFunctions)
            return NOS_RESULT_SUCCESS;

        NOS_RETURN_ON_FAILURE(RegisterPrintOnLogPaneNode(outFunctions[0]));
        return NOS_RESULT_SUCCESS;
    }
};

NOS_EXPORT_PLUGIN_FUNCTIONS(PluginExtension);
```

</details>

#### Comfort declaration requirements
If you build the plugin and try to load it from the engine, you'll get ***"Plugin is trying to register a node that doesn't exist in its node definitions"*** error. This is because Nodos reads node configuration (**.noscfg**) and node definition (**.nosdef**) files to create node properties.

Configuration file describes the whole plugin such as; compiled binary path, node definition file paths, plugin's dependencies to subsystems and other plugins, custom data types ([flatbuffers](https://flatbuffers.dev/) based) and many more. More detailed info is available on [Plugins](../plugins/index.md).

To add a node, create a **.nosdef** file. It should have JSON schema. You can define how many nodes you want as a list of nodes under the header **nodes**.

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
            "class_name": "PrintOnLog",
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
            "name": "thirdex",
            "version": "0.1.0"
        },
        "display_name": "thirdex",
        "description": "",
        "dependencies": []
    },
    "binary_path": "./Binaries/thirdex",
    "node_definitions": [
        "PrintOnLog.nosdef"
    ],
    "defaults": [],
    "custom_types": [],
    "associated_nodes": [
        {
            "category": "Test",
            "class_name": "PrintOnLog",
            "display_name": "Test to Log"
        }
    ]
}
```
</details>

</details>

Now you should be able to see your first node in the node graph. In examples above, we created a node that prints to **Log pane** only if the pin's value changes. So create an **Add** node and sets its input values. After you connect it to the Message pin, `OnPinValueChanged()` will be called and it will print the value. Everytime you change the pin's value by changing output value of the connection, it'll be printed.
