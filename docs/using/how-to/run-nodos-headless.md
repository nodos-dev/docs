# Run Nodos headless

`nosLauncher` hosts the engine and executes graphs. The editor is a separate client, so you can run
a graph with no editor at all — for playout, automated tests, or CI.

## Load and run a graph

```shell
nosLauncher --load-graph /path/to/graph.nos
```

The launcher loads the graph and begins executing whatever paths it contains. Nothing else is
required; scheduling comes from the thread and sink nodes already in the graph.

To resume whatever was running last:

```shell
nosLauncher --load-last-graph
```

## Useful flags for unattended runs

```shell
nosLauncher \
  --load-graph show.nos \
  --load-graph-plugins \
  --exit-silently-if-duplicate \
  --disable-beacon
```

`--load-graph-plugins`
:   Loads the modules listed in the graph's `loaded_modules` field once all other modules are
    loaded. Without it, a graph referencing a module that is installed but not loaded will not run
    correctly.

`--exit-silently-if-duplicate`
:   Suppresses the dialog when an instance is already running. Required for anything unattended —
    otherwise a second launch blocks on a message box nobody will click.

`--disable-beacon`
:   Stops the UDP discovery broadcast. Use on networks where you do not want engines announcing
    themselves.

`--disable-process-auto-launch`
:   Stops the engine from launching processes referenced by process nodes when they are not already
    running. Use when an orchestrator owns process lifetimes.

`--live`
:   Runs in live mode.

`--force-all-top-level-outputs`
:   Forces the scheduler to treat all top-level outputs as required.

The complete list is in the [Launcher CLI reference](../reference/launcher-cli.md).

## Override settings without editing files

Any engine setting can be overridden per launch:

```shell
nosLauncher --override-settings \
  connection_settings/logging_service_address="0.0.0.0:50151" \
  connection_settings/node_graph_service_address="0.0.0.0:50152"
```

The syntax is `path/to/key=value`, and multiple pairs may follow the flag. The persisted defaults
live in `Engine/<version>/Config/EngineSettings.json`; overrides do not modify that file, which
makes them safe for parallel or ephemeral runs.

Defaults worth knowing:

| Service | Setting | Default |
|---|---|---|
| Logger | `connection_settings/logging_service_address` | `0.0.0.0:50051` |
| Editor | `connection_settings/node_graph_service_address` | `0.0.0.0:50052` |
| App | `connection_settings/app_service_address` | `0.0.0.0:50053` |

## Running several instances on one machine

Give each one its own ports and silence the duplicate-instance dialog:

```shell
nosLauncher --load-graph a.nos --exit-silently-if-duplicate \
  --override-settings \
    connection_settings/logging_service_address="0.0.0.0:50151" \
    connection_settings/node_graph_service_address="0.0.0.0:50152" \
    connection_settings/app_service_address="0.0.0.0:50153"
```

Repeat with a different port block for each instance. Applications connecting via the
[Application SDK](../../developing/how-to/connect-an-external-app.md) must target the matching `app_service_address`.

## Attach an editor later

A headless engine is still a normal engine. Start `nosEditor` and connect it to the launcher's
editor service address to inspect or modify a running graph, then disconnect again — the graph
keeps running.

The discovery beacon (UDP port `11000` by default) is how editors find reachable engines on the
network. If you disabled it, connect by address instead.

## Run a plugin's test graphs

For CI on a plugin repository, `nodos test` walks plugins in a folder, finds graph files
(`.nos` and `.nosa`) under each plugin's `Tests/` directory, and runs
`nosLauncher --load-graph --load-graph-plugins` for each:

```shell
nodos test --plugins-folder ./Module --timeout 60
```

Point it at a specific engine with `--engine-dir` if the workspace has several installed.

## Managing the process

From a workspace, `nodos` wraps the lifecycle:

```shell
nodos engine status
nodos engine restart
nodos engine stop
```
