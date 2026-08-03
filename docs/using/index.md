# Using Nodos

Installing Nodos, building and running graphs, and managing the modules that provide nodes. This
is the ground floor — if you are here to write a plugin, do this part first, then go to
[Developing for Nodos](../developing/index.md).

Pages are grouped by what you need from them.

## :material-school: Tutorials

Lessons. Guided from a known starting point to a working result, meant to be followed start to
finish without deciding anything yourself.

- **[Your first graph](tutorials/your-first-graph.md)** — install Nodos, open the editor, and build
  a graph that adds two numbers and shows the result. Introduces threads, sinks and pins, and why a
  graph needs an execution root at all. *About 15 minutes, no C++.*
- **[Running an AI model](tutorials/running-an-ai-model.md)** — load an ONNX model, convert a
  texture into the tensor layout it wants, run inference on the GPU, and convert the result back.
  *About 30 minutes, needs an AI bundle.*

## :material-wrench: How-to guides

Recipes. One problem each, for someone who already knows what they want.

- **[Install Nodos](how-to/install-nodos.md)** — installers, workspaces, bundles, requirements.
- **[Manage packages](how-to/manage-packages.md)** — install, remove, list and inspect modules.
- **[Run Nodos headless](how-to/run-nodos-headless.md)** — load a graph and run it without an
  editor, for CI and unattended playout.

## :material-book-open-variant: Reference

Descriptions of the machinery. Look things up here; these pages do not teach.

- **[nodos CLI](reference/nodos-cli.md)** — every command of the workspace and package manager,
  including the authoring and publishing commands used in
  [Developing for Nodos](../developing/index.md).
- **[Launcher CLI](reference/launcher-cli.md)** — `nosLauncher` arguments, settings overrides,
  service addresses.

## :material-lightbulb-on: Explanation

Background. Read these when a behaviour surprises you.

- **[Architecture](explanation/architecture.md)** — the processes that make up a running Nodos
  system and how they talk to each other. Explains why closing the editor does not stop your graph.
- **[Scheduling and execution](explanation/scheduling.md)** — why a graph needs threads and sinks,
  what recompiles when you edit, and in what order things run. Worth reading whether you write C++
  or not.

## Something not working?

[Get help](../about/get-help.md) covers where to report problems, what to collect first, and the
most common causes of a graph doing nothing.
