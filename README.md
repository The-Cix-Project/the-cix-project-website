# Cix Project website

The public home for the Cix Project: the initiative that stewards Cix OS and
the tools around it, including CBS (Cix Build System).

## Develop locally

```sh
python3 tools/dev-server.py
```

Open <http://127.0.0.1:8080>. The server serves the `site/` directory and
returns the branded `404.html` page for missing paths.

## Check and publish

```sh
python3 scripts/check-site.py
```

The site is static. Publish the contents of `site/` to any static host, or use
the included Caddy example in `deploy/Caddyfile`. For the VM workflow used by
the Cix website, see [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) and run
[`deploy/install-vm.sh`](deploy/install-vm.sh) on the target Debian VM. Keep the
GitHub links and project map in `site/index.html` current when repositories change.

## Source of truth

Project facts are drawn from the public Cix repository and companion project
repositories. Brand direction follows `../new_project/docs/brand/brand-guidelines.md`
in the local workspace: direct, inspectable, source-native, and free of inflated
claims.
