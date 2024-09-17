# Welcome to Nodos

Welcome to the official documentation for **Nodos**, an advanced node-based graph scheduling system.

Use the navigation on the left to browse through the different sections of the documentation.

# Quick Start

{%set activeVersion = "1.3.0.b3497" %}
Download the latest build as a .zip file [here (version {{ activeVersion }})](https://github.com/nodos-dev/index/releases/download/nodos.bundle.standard-{{ activeVersion }}/Nodos-{{ activeVersion }}-bundle-standard.zip "{{ activeVersion }}") 

Extract the file and run Nodos.exe to see the Editor

![extract-zip]({{ remote_images_folder }}extract_zip.gif?raw=true "Extract Zip")

Now let's add 2 unsigned integer numbers and use Show Status node to display it on the NodeGraph.

Right-click on node graph to display node list, create Thread and Sink nodes to execute your graphs and then you're ready for your journey!

![add-2-integers]({{ remote_images_folder }}Add2Integers.gif?raw=true "Add 2 integers")


# System Requirements

- **Operating System**: Windows 10 or later
- **GPU**: The GPU driver should be supporting Vulkan 1.2 specs.
- **Development Environment**: C++ compiler (e.g., MSVC), Shader compiler (for GLSL/HLSL)
- **Dependencies**: Standard C++ libraries, Shader compilation tools

# License

Nodos is distributed under a custom license that is very permissive, even for commercial use. For detailed information, please refer to the LICENSE file included with the distribution.
