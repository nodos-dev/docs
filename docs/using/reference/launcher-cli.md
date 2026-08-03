# Launcher CLI

`nosLauncher` is the host process for the Nodos engine. It parses these arguments, loads engine
settings, starts the gRPC services, loads `nosEngine`, and begins execution.

Editors connect to the launcher; the graph runs in the launcher's process, not the editor's.

```plaintext
nosLauncher [options]
```

## Options

`--load-graph <path>`
:   Load a graph from a file. The launcher exits with an error if the path does not exist. Graph
    files use the `.nos` and `.nosa` extensions.

`--load-last-graph`
:   Load the last saved graph. Default `false`.

`--load-graph-plugins`
:   Load the modules listed in the graph's `loaded_modules` field after all other modules are
    loaded. Default `false`.

`--force-all-top-level-outputs`
:   Force the scheduler to treat all top-level outputs as required. Default `false`.

`--live`
:   Run in live mode. Default `false`.

`--exit-silently-if-duplicate`
:   Do not show an information dialog when an instance is already running. Default `false`.
    Required for unattended runs.

`--disable-process-auto-launch`
:   Do not automatically launch processes referenced by process nodes when they are not already
    running. Default `false`.

`--override-settings <key=value>...`
:   Override engine settings, including nested config values. Accepts any number of pairs.

`--beacon-ip-address <address> <mask>`
:   Beacon IP address and mask, as two arguments. For example
    `--beacon-ip-address "192.168.101.0" "255.255.255.0"`.

`--disable-beacon`
:   Disable the discovery beacon. Default `false`.

`-h, --help`
:   Show help and exit.

`-v, --version`
:   Print version information and exit.

## Settings overrides

`--override-settings` takes `path/to/key=value` pairs, addressing into the engine settings
structure:

```shell
nosLauncher --override-settings \
  connection_settings/logging_service_address="0.0.0.0:50151" \
  connection_settings/node_graph_service_address="0.0.0.0:50152"
```

Overrides apply to the run only. They do not modify the settings file, which makes them safe for
parallel or ephemeral instances.

## Services and defaults

The launcher hosts three bidirectional gRPC services.

| Service | Settings key | Default | Purpose |
|---|---|---|---|
| Logger | `connection_settings/logging_service_address` | `0.0.0.0:50051` | Log and watch transport |
| Editor | `connection_settings/node_graph_service_address` | `0.0.0.0:50052` | Graph and editor operations |
| App | `connection_settings/app_service_address` | `0.0.0.0:50053` | External process integration |

The discovery beacon broadcasts engine status over UDP on port `11000` by default. Editors listen
for it to discover reachable engines.

## Files

| Path | Contents |
|---|---|
| `Engine/<version>/Config/EngineSettings.json` | Persisted engine settings. Created with defaults if absent. |
| `Engine/<version>/Logs/` | Runtime logs. |
| `Engine/<version>/EULA_CONFIRMED.json` | EULA acceptance state. |
| `Engine/<version>/EULA_UNCONFIRMED.json` | Pending EULA state. |

## See also

- [Run Nodos headless](../how-to/run-nodos-headless.md) — recipes using these flags.
- [Architecture](../explanation/architecture.md) — why the launcher and editor are separate.
