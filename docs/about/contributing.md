# Contributing

Nodos module sources are open, and reading them is the fastest way to understand how something
works. Fixes and improvements are welcome.

## What you can contribute to

| | Where | |
|---|---|---|
| **Documentation** | [`nodos-dev/docs`](https://github.com/nodos-dev/docs) | This site. |
| **Modules** | `nodos-dev/modules`, `nodos-dev/sys-vulkan`, `nodos-dev/mediaio`, `nodos-dev/audio`, `nodos-dev/decklink`, and others | Plugins and subsystems shipped in the bundles. |
| **Toolchain** | [`nodos-dev/workspace`](https://github.com/nodos-dev/workspace) | The `nodos` CLI and the CMake toolchain. |

The engine itself is not publicly available. Engine bugs are still worth reporting — see
[Get help](get-help.md) — they just get fixed on our side rather than through a pull
request.

## Modules

Module repositories are ordinary Nodos plugins and build the same way yours does. Clone one into a
workspace's `Module/` directory, or build it in place:

```shell
nodos dev gen --plugin-dirs "/path/to/the/module"
nodos dev build
```

Then:

1. Branch from `main`.
2. Make the change, and load it into a real graph to check it.
3. Add or update a test graph under the module's `Tests/` folder where it makes sense —
   `nodos test` runs these.
4. Open a pull request.

If a workspace spans several module repositories, `nodos dev status` and `nodos dev pull` operate
across all of them at once.

### Conventions

- C++ constants are `SCREAMING_SNAKE_CASE`, not `kCamelCase`.
- Use `nos::ObjectRef` / `nos::TypedObjectRef` over raw `nosObjectId` and C resource structs.
- Bump the major version in a manifest on an API break. Leave dependency versions alone unless
  that is the change you are making.
- Adding a node means three things agreeing: the `.nosnode` `class_name`, the string in
  `NOS_BIND_NODE_CLASS`, and the `NOS_NODE(...)` entry.
- Fill in `name_aliases` in `menu_info`. It is the cheapest usability improvement available to a
  node author.

## Documentation

These docs are built with [MkDocs](https://www.mkdocs.org/) and
[Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).

```shell
git clone --recurse-submodules https://github.com/nodos-dev/docs.git
cd docs
pip install -r requirements.txt
mkdocs serve
```

Then open <http://127.0.0.1:8000/>.

Check your change builds cleanly before opening a pull request:

```shell
mkdocs build --strict
```

### Structure

Pages are organised **by audience first**, then by the four [Diátaxis](https://diataxis.fr/) modes
within each:

```
docs/
├── using/           Install, build and run graphs, manage modules
│   ├── tutorials/  how-to/  reference/  explanation/
├── developing/      Plugins, subsystems, application integration
│   ├── tutorials/  how-to/  reference/  explanation/
└── about/           Get help, licensing, contributing
```

When adding a page, put it in the audience *and* the mode it belongs to, and keep it in that mode:

| Mode | Serves | Reads like |
|---|---|---|
| **Tutorial** | Learning | A lesson. Guided, start to finish, no decisions for the reader. |
| **How-to** | A goal | A recipe. One problem, assumes competence. |
| **Reference** | Information | A description. Complete, neutral, no instruction. |
| **Explanation** | Understanding | A discussion. Context and rationale, no steps. |

The common failure is a page that tries to teach *and* be looked up in. Split it instead — a
reference page and a how-to that links to it beat one page doing both badly.

Pages serving both audiences live under `using/`, since developers are a superset of users —
everyone installs Nodos and builds graphs. Cross-link from `developing/` rather than duplicating.

### Conventions

- **Write for users and plugin developers.** Describe what is observable from a shipped install and
  the public SDK: CLI behaviour, manifest and node definition formats, SDK callbacks and their
  ordering, file layouts under the engine install. Do not document engine internals — class names,
  internal source paths, or implementation strategy — since readers cannot see them and they change
  without notice.
- **Version-dependent facts get a marker.** Current-line behaviour in an `!!! info` admonition,
  legacy behaviour in a collapsed `??? warning` block, so the current path reads uninterrupted.
- **Version numbers come from config.** Declare them under `extra:` in `mkdocs.yml` and reference
  them as `{{ "{{ nodos_version }}" }}`, `{{ "{{ plugin_sdk_version }}" }}` and so on, rather than
  writing them into prose.
- **Images** live in `docs/images/` and are referenced with relative paths.
- **Verify against the SDK before documenting an API.** Check the headers under
  `Engine/<version>/SDK/` or `Package/Downloaded/nodos.sdk.plugin/<version>/Include/`. Several
  pages in an earlier version of these docs described APIs that had since changed.
- **Moving a page means adding a redirect.** Add an entry to `redirect_maps` in `mkdocs.yml` so
  existing links keep working.

## Reporting problems

See [Get help](get-help.md) for where to report and what to include.
