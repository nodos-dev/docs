# Instructions

{%set integrateShaderTitle = "Integrate Shaders" %}
{%set buildAGraphTitle = "Build a Node Graph" %}
{%set runGraphTitle = "Run the Graph" %}
1. **{{integrateShaderTitle}}**: Write your shaders in GLSL or HLSL. Nodos will handle the compilation and runtime linking automatically.
2. **{{buildAGraphTitle}}**: Use the Nodos interface to connect and configure your nodes, creating the desired graph structure.
3. **{{runGraphTitle}}**: Execute the node graph within Nodos to see your code and shaders in action.

## {{integrateShaderTitle}}



## {{buildAGraphTitle}}

You can find the nodes available in your engine by right-clicking on the node graph.

## {{runGraphTitle}}

In Nodos, you have to handle the running thread's behaviour from the beginning. Execution of a set of nodes start from a Thread node and ends with a Sink node.

There is also a Threaded Sink node to execute basic nodes