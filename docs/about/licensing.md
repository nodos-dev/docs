# Licensing

## Personal and academic use

**Free.**

Available to individual users and academic institutions for non-commercial, educational or research
purposes.

## Commercial use

**$1850 per engine, annual subscription.**

Required for companies and organisations using Nodos for commercial or profit-driven activity.

## The EULA

Nodos prompts you to accept its EULA the first time you install an engine into a workspace.
Acceptance is recorded per engine, in `EULA_CONFIRMED.json` under the engine install.

For unattended installs — CI, provisioning scripts — accept up front:

```shell
nodos --silently-agree-eula get
```

This agrees for every engine installed in the workspace.

## Third-party software

Modules that bundle third-party code declare it through `third_party_software` in their
[manifest](../developing/reference/plugin-manifest.md), pointing at a licence JSON file. Engine-level
third-party licences are listed in `Binaries/THIRD_PARTY_LICENSES.json` under the engine install.

## Questions

Licensing and commercial enquiries: [contact@nodos.dev](mailto:contact@nodos.dev).

The authoritative terms are in the LICENSE file included with your distribution. This page is a
summary, not the licence.
