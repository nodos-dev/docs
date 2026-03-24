Official documentation of Nodos.

Production deployments now go through the VPS deployment workflow in GitHub Actions instead of GitHub Pages.

# How To Write Docs

Nodos documentation is written using markdown syntax and we use MkDocs and Material theme for now.
If you want to contribute or extend Nodos documentation, you can follow these steps:

```
git clone https://github.com/mediaz/docs.git
pip install mkdocs
pip install mkdocs-material
pip install mkdocs-macros-plugin
```

To start serving locally from http://127.0.0.1:8000/
```
mkdocs serve
```
Then you should create a pull request for your commit in our documentation.

## Production Deployment

The production workflow builds the MkDocs site, uploads the generated static files to the VPS, configures nginx, and runs a health check.

It writes these nginx config paths on the VPS:

- `/etc/nginx/sites-available/nodos-docs.conf`
- `/etc/nginx/sites-enabled/nodos-docs.conf`

Required GitHub Actions configuration:

- Repository variable `VPS_HOST`
- Repository variable `VPS_USER`
- Repository variable `VPS_PORT` (optional, defaults to `22`)
- Repository variable `NODOS_DOCS_BASE_URL`
- Repository variable `NODOS_DOCS_PORT` (optional, defaults to `8082`)
- Repository secret `VPS_SSH_PRIVATE_KEY`
