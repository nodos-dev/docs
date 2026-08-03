# Versioning and SDK lines

Nodos has several version numbers in play at once, and they do not move together. Knowing which one
you are looking at resolves most "which version do I need?" confusion.

## The four version numbers

**Engine version** — `{{ nodos_version }}.0`, `{{ legacy_version }}.2`. The Nodos release line. It
determines the manifest and node definition formats, and the build workflow.

**Plugin SDK version** — `{{ plugin_sdk_version }}`. The in-process plugin authoring API. This is
what goes in a manifest's `sdk_version`, and it is a large number that has nothing to do with the
engine version.

**Process SDK version** — `{{ process_sdk_version }}`. The out-of-process Application SDK. Versions
independently of the plugin SDK, because they are different contracts with different consumers.

**Package version** — your module's own `info.id.version`. Independent of all of the above.

An engine install records the first three:

```json title="Engine/<version>/SDK/info.json"
{
	"version": "{{ nodos_version }}.0",
	"plugin_sdk_version": "{{ plugin_sdk_version }}.0",
	"process_sdk_version": "{{ process_sdk_version }}.0"
}
```

Query them with `nodos sdk-info <version> [engine|plugin|subsystem|process]`.

## Release lines

Two lines are current.

**Nodos {{ nodos_version }}** is the current line. Manifests are `.nosplugin`, node definitions are
`.nosnode` files discovered under `Nodes/`, CMake targets are generated from manifests, and the
entry point comes from `PluginMain.inl`.

**Nodos {{ legacy_version }}** is still supported and still shipping. Manifests are `.noscfg` and
`.nossys`, node definitions are `.nosdef` listed explicitly in the manifest, every plugin needs its
own `CMakeLists.txt`, and the entry point is hand-written.

Both lines get releases. `nodos get` currently defaults to `--version {{ legacy_version }}`, so ask
for {{ nodos_version }} explicitly if that is what you want:

```shell
nodos get --name nodos.bundle.standard --version {{ nodos_version }}
```

Migration is mechanical and mostly deletion:
[Migrate a plugin to {{ nodos_version }}](../how-to/migrate-1-3-to-1-4.md).

## Version resolution

Versions are semantic. Where you supply one — `nodos install`, a manifest dependency — it is
interpreted as a **minimum within a minor line**, not an exact pin.

Given `8.0`, the resolver accepts any installed `x` where `8.0 <= x < 8.1`, and fetches the latest
such version if none is installed.

This is the useful default. Patch releases within a minor version are compatible by definition, so
pinning exactly means you stop receiving fixes for no benefit. When you do need an exact version,
`--exact` is there.

`latest`, and versions without a minor component, are rejected. That is deliberate: a dependency on
"whatever is newest" is not a dependency specification, it is a bug waiting for someone else's
release.

## When to bump your version

**Major** — on any API break. For a plugin: a change to node pin contracts that existing graphs
depend on. For a subsystem: any change to the public header's struct layout or function signatures.
Consumers resolving `8.0` will not pick up your `9.0`, which is exactly what you want when the
contract changed.

**Minor** — new capability, backward compatible. Consumers resolving `8.0` will not pick up `8.1`
automatically either, so a minor bump is a deliberate opt-in for them.

**Patch** — fixes within a compatible surface. Consumers resolving `8.0` *do* pick these up. This
is where fixes belong.

One rule worth stating plainly: do not change a dependency's version unless that is the change you
are making. Bumping dependencies opportunistically alongside unrelated work is how a compatible
patch release quietly becomes a breaking one.

## Schema versions

Manifests and node definitions carry `schema_version`, e.g. `"1.4-v1"`. This versions the file
format itself, not your module, and lets the toolchain read older files as the format evolves.

## SDK compatibility for applications

Because the Application SDK is loaded dynamically rather than linked, header/library mismatch is
not a link error — it is undefined behaviour at runtime. Hence `CheckSDKCompatibility`, called with
the version your headers declare, before anything else.

Build systems should also verify the SDK is present at all:

```shell
nodos sdk-info {{ process_sdk_version }}.0 process
```

It fails if that version is not installed, so it works as a build-time gate.

## Bundles

A bundle is an engine plus a preinstalled module set, versioned with the engine:
`nodos.bundle.standard-{{ nodos_version }}.0.b3889`. The build number is part of it — bundles are
built and published per platform.

Bundle contents are not a compatibility contract. A module you install separately afterwards is
resolved the same way as one that came in the bundle.

## See also

- [Migrate a plugin to {{ nodos_version }}](../how-to/migrate-1-3-to-1-4.md)
- [Manage packages](../../using/how-to/manage-packages.md)
- [Publish a package](../how-to/publish-a-package.md)
