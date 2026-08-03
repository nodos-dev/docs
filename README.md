# Nodos documentation

Source for the official Nodos documentation, built with [MkDocs](https://www.mkdocs.org/) and
[Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).

## Working locally

```shell
git clone https://github.com/nodos-dev/docs.git
cd docs
pip install -r requirements.txt
mkdocs serve
```

Serves on <http://127.0.0.1:8000/>.

Before opening a pull request, check the site builds cleanly:

```shell
mkdocs build --strict
```

The changelog is a git submodule, so clone with `--recurse-submodules` or run
`git submodule update --init` if `docs/changelog/` is empty.

## Structure

Pages are organised **by audience first**, then by the four [Diátaxis](https://diataxis.fr/) modes
within each:

```
docs/
├── using/           Install, build and run graphs, manage modules
│   ├── tutorials/  how-to/  reference/  explanation/
├── developing/      Plugins, subsystems, application integration
│   ├── tutorials/  how-to/  reference/  explanation/
├── about/           Get help, licensing, contributing
└── changelog/       git submodule
```

Diátaxis explicitly allows the four types to sit under another axis when a product has distinct
audiences; that is what this is. Put a new page in the audience *and* the mode it belongs to:

| Mode | Serves | Reads like |
|---|---|---|
| Tutorial | Learning | A lesson. Guided start to finish, no decisions for the reader. |
| How-to | A goal | A recipe. One problem, assumes competence. |
| Reference | Information | A description. Complete, neutral, no instruction. |
| Explanation | Understanding | A discussion. Context and rationale, no steps. |

The usual failure mode is a page that tries to teach *and* be looked up in. Split it — a reference
page plus a how-to that links to it beats one page doing both badly.

**Pages that serve both audiences live under `using/`**, on the principle that developers are a
superset of users: everyone installs Nodos and builds graphs. `using/reference/nodos-cli.md` covers
the whole CLI including the authoring and publishing commands, and `developing/index.md` links to
it. Do not duplicate a page into both trees — cross-link instead.

### Conventions

- **Audience is Nodos users and third-party plugin developers.** Document what is observable from a
  shipped install and the public SDK: CLI behaviour, manifest and node definition formats, SDK
  callbacks and their ordering, file layouts under the engine install. Do **not** document engine
  internals — internal class names, private source paths, or implementation strategy. Readers
  cannot see the engine repository, and those details change without notice.
- **Versions come from config.** Declare them under `extra:` in `mkdocs.yml` and reference them as
  `{{ nodos_version }}`, `{{ plugin_sdk_version }}`, `{{ process_sdk_version }}`,
  `{{ legacy_version }}`, `{{ cpp_version }}`. Do not write version numbers into prose.
- **Mark version-dependent facts.** Current-line behaviour in an `!!! info` admonition; legacy
  behaviour in a collapsed `??? warning` block, so the current path reads uninterrupted.
- **Images live in `docs/images/`** and are referenced with relative paths.
- **Verify against the source.** Check the API you are describing in the Nodos workspace before
  documenting it, rather than copying an older page.
- **Old URLs get redirects.** Moving or renaming a page means adding an entry to `redirect_maps`
  in `mkdocs.yml`.

## Deployment

`.github/workflows/deploy.yml` is triggered manually (`workflow_dispatch`). It builds the site with
`mkdocs build --strict`, uploads the archive to the VPS, extracts it into a timestamped release
directory, repoints the `current` symlink, runs a health check against `/health`, and tags the
deployed commit.

nginx configuration is **not** managed by this workflow. It is maintained on the VPS at:

- `/etc/nginx/sites-available/nodos-docs.conf`
- `/etc/nginx/sites-enabled/nodos-docs.conf`

Required GitHub Actions configuration:

| Kind | Name | Notes |
|---|---|---|
| Variable | `VPS_HOST` | |
| Variable | `VPS_USER` | |
| Variable | `VPS_PORT` | Optional, defaults to `22` |
| Variable | `NODOS_DOCS_BASE_URL` | Used to derive the `Host` header for the health check |
| Variable | `NODOS_DOCS_PORT` | Optional, defaults to `8082` |
| Secret | `VPS_SSH_PRIVATE_KEY` | |
