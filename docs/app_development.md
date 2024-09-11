# Application Development
This page is for users that already have an application and want it to communicate with Nodos engine as a node. With this way, users can make changes on their applications using Nodos Editor.

When an application is connected to engine, engine creates a node for it. Application is free to modify this node but can't add another node. This means, an application can have only one node inside of an engine instance.

Let's create an example console application that gets a float input from Nodos and prints it on the console.

#### Check your Nodos AppSDK version

Nodos is a evolving project, so its AppSDKs. This means, there can be version compatibility issues between your applications and Nodos. To solve this, AppSDK has its own version. You can see version of your downloaded engine's AppSDK as `process_sdk_version` in **info.json** file under your engine's SDK folder.

Nodos also has a command to if the intended SDK version is compatible with current one. You can parse the output from command below in your build systems to check against incompatibility and find AppSDK's directory:

`nodos sdk-version <intended_sdk_version_here> process`

#### Include Nodos AppSDK to your solution

All header files you'll need from Nodos is under the `include` folder of AppSDK's directory (the path outputted from command above). So we recommend you to include it from your project settings.

Our headers are written in {{required_cpp_version}} standard, so you must move your project to {{required_cpp_version}}.

#### Load AppSDK dynamic library and its functions

Using your platform's dynamically linked shared object APIs, load **nosAppSDK** dynamic library to your application. After that, you must load the functions mentioned below (by using `GetProcAddress()` on **Windows** for example) and cast them to their related function types.

##### FunctionName->FunctionType table

`CheckSDKCompatibility` cast to `nos::app::FN_CheckSDKCompatibility*`

`MakeAppServiceClient` cast to `nos::app::FN_MakeAppServiceClient*`

`ShutdownClient` cast to `nos::app::FN_ShutdownClient*`

##### Function descriptions

**CheckSDKCompatibility:** Checks against version conflicts. Call this function with the version your headers define. If headers you included isn't compatible with the one that's dynamic library is compiled with, it fails.

**MakeAppServiceClient:** Creates a `AppServiceClient` object that you can use access the gRPC. With this object, you can connect to any Nodos engine you want over network. We also use this object to register application event callbacks because our gRPC communication with apps are asynchronous.

**ShutdownClient:** Delete all resources related to client. If you lost connection to Nodos (or want to disconnect), use this to clear any remaining data. Call this after unregistering delegates.

#### Define EventDelegates

As said above, our gRPC communication is asynchronous. We uses event delegation design pattern in Nodos to handle callbacks to applications. If you want to get notified about the changes made to your node on the graph (as you should, because there are no other ways to communicate with Nodos), you should implement it.

**Derive** `nos::app::IEventDelegates` first.

**Define** all pure virtual functions on derived class and create a object of it.

**Call** `client->RegisterEventDelegates()` with the object. All this does is storing the object in nosAppSDK side to pass it to the Nodos instance automatically using gRPC when you connect to an instance.

!!! info
    When you connect to Nodos, you can check which events called when. {{to_do_text}}


#### Connect to a Nodos instance

You already defined the IP address and the port of your Nodos instance in `MakeAppServiceClient()` call. So run a Nodos instance with the specified address to be able to connect.

!!! info
    If you want to connect to a Nodos that has different address, you gotta create another `AppServiceClient` object after destroying the one that already exist.

**Call** `AppServiceClient::IsConnected()` to check your connection to Nodos instance.

**Call** `AppServiceClient::TryConnect()` to try a connection.

#### Use the AppNode in NodeGraph

You can see your application's name you defined while creating `AppServiceClient` object in **{{applications_pane_name}}** pane. If you drag and drop it to **NodeGraph**, `onNodeUpdated()` event will be called.

After this, you are free to experiment with which events are called when. As this tutorial's main purpose is to teach you how you can connect to Nodos, this is enough. {{to_do_text}}

#### Suggestions

#### Finished

!!! info
    You can look into our [Vulkan](https://github.com/mediaz/nos-vulkan-app-sample) and [DirectX12](https://github.com/mediaz/nos-dx-app-sample) sample applications for more information. Both applications is organized like below:
    
    Create a window & initialize the graphics API (note that Nodos has no DX12 backend)
    
    Wait for a connection to Nodos

    Add an input and an output pin to the application node
    
    Get the texture handle from input pin
    
    Render on top of it and present it on the application window
    
    Send the final rendered texture to Nodos using output pin.