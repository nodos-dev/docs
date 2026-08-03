# Scheduling and execution

The first thing that surprises people about Nodos is that connecting nodes together does not make
them run. A graph needs a **thread** to originate execution and a **sink** to terminate it, and
only nodes on a path between the two are scheduled at all.

That is not an oversight. It is the central design decision, and most of how Nodos behaves follows
from it.

## Why explicit scheduling

Nodos targets real-time work: video at a fixed frame rate, GPU pipelines with bounded latency,
broadcast output that must not drop a frame. In that setting, *when* and *how often* a node runs is
part of the problem being solved, not an implementation detail to be inferred.

A dataflow system that evaluates whatever is connected has to guess. It re-evaluates when inputs
change, or when someone pulls on an output, and the rate falls out of whatever happens to be
upstream. That is fine for a shader graph or a build system. It is not fine when the answer needs
to be "exactly 59.94 times a second, on this thread, with three frames of GPU buffering".

So Nodos makes you say it. The cost is the extra ceremony of a Thread and a Sink node in every
graph. The benefit is that rate, threading and buffering are visible in the graph rather than
emergent.

## The pieces

**Thread nodes** (`nos.Thread`) represent actual runner threads. Execution originates here. A graph
with two thread nodes genuinely runs work on two threads.

**Sink nodes** terminate a path and set its rate. `Sink FPS` defaults to 60. Sinks also carry the
GPU-related properties — `HasGPUWork`, `GPUFrameBuffering` — because the end of a path is where you
decide how far ahead of the GPU the CPU may run.

**Execution pins** (`nos.exe`) carry no value. They express ordering: that this node runs after that
one. Data pins carry values; execution pins carry the fact of execution. Keeping them separate is
what lets a node's data dependencies and its scheduling position differ.

**Paths** are what a graph is turned into before it runs: a sequence of nodes that will execute
together, in order, driven by a thread and terminated by a sink.

## Compilation

Editing a graph does not schedule it. Certain changes mark the graph for recompilation, and the
engine turns nodes and connections into execution paths before anything runs.

You do not trigger this and cannot inspect it directly, but it is worth knowing it happens, because
it explains what is cheap and what is not while a graph is live.

### What triggers recompilation

Structural and scheduling-relevant changes: thread, function or event activation changes;
connections created or removed; nodes and pins created, deleted or activated; pin type changes and
live changes.

Changing a *value* does not recompile. Changing the *shape* does.

In practice: dragging a slider on a running graph is cheap. Rewiring it is not, and a large graph
will show a brief hitch as it recompiles.

!!! tip "Keep switch chains shallow"
    Branching is the one structure whose compile cost grows disproportionately. Long chains of
    `Switch` nodes feeding into one another get expensive to compile, quickly — the cost grows with
    how deeply switches are nested along a single route, not with how many there are overall.

    If a graph has become slow to edit, flattening nested branches is usually the fix. Selecting
    between a few precomputed inputs at one point beats a cascade of switches along the path.

## Execution

Once compiled, paths are distributed across runner threads and executed.

For each frame on a runnable path, plugin callbacks fire in this order:

1. Path control transitions — stop, start initiated, start.
2. **Frame begin** — plugin-wide `OnBeginFrame`, then node-level `OnBeginFrame`.
3. **For each node** — plugin-wide `OnPreExecuteNode`, then the node's `ExecuteNode` (or
   `CopyFrom`, or a function or event command), then plugin-wide `OnPostExecuteNode`.
4. **Frame end** — plugin-wide `OnEndFrame`, then node-level `OnEndFrame`.
5. Path stop triggers `OnPathStop`.

This ordering is the contract your node code can rely on. It is also why `ExecuteNode` is called
*because the scheduler decided the node is due*, not because an input changed — if you want to
react to a value changing, that is `OnPinValueChanged`, a different callback at a different point.

Nodes can migrate between runner threads when the graph is recompiled. `OnEnterRunnerThread` and
`OnExitRunnerThread` let you react; do not assume thread affinity between frames.

## Dirtiness and `always_execute`

Within a scheduled path, a node executes when one of its inputs is dirty. That default is right for
pure transformations — no input change, no new output, no work.

It is wrong for anything that produces something new each frame. Setting `always_execute` in the
node definition opts out of the dirty check. Use it for:

- time-varying sources — a clock, a signal generator,
- per-frame side effects or edge detection,
- threaded sources pushing data in from outside the graph,
- functions that mutate internal state without writing to a pin.

Note that `SetPinValue` on an *input* pin dirties the node and re-triggers execution. A callable
function that writes a pin therefore does not need `always_execute` to take effect. Reaching for it
when the dirty mechanism would have worked just burns CPU every frame, on every instance of your
node, in every graph that uses it.

## Node lifecycle

A node's life has two overlapping tracks: its place in the graph, and whether it is currently
runnable.

Structurally, creating a node fires `OnCreate`, then pin callbacks as its pins are populated, and
may request a recompile. Deleting it fires `OnDestroy`.

Runnability is separate. A node that exists is not necessarily scheduled: it needs an active
context and a path to a sink. This is why a freshly placed node sits there doing nothing until you
wire it into an execution path — the most common "my node isn't running" cause, and the first thing
to check.

## See also

- [Your first graph](../tutorials/your-first-graph.md) — build the thread/sink pattern once and it
  stops feeling arbitrary.
- [Node definition](../../developing/reference/node-definition.md) — `always_execute`, execution pins.
- [Plugin API](../../developing/reference/plugin-api.md) — the execution callbacks in full.
