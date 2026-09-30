# Production deployment

This repository contains the same deployment pattern used by the Cix website:
a bare Git mirror, validated release directories, an atomic `current` symlink,
a five-minute systemd updater, and Caddy-managed HTTPS.

## DNS

Point both names at the production VM:

```text
cixproject.org       A/AAAA  <production-vm>
www.cixproject.org   A/AAAA  <production-vm>
```

The installer configures both names. Caddy can obtain certificates after both
names resolve and ports 80 and 443 reach the VM.

## Install

On the Debian VM, as root:

```sh
git clone https://github.com/The-Cix-Project/the-cix-project-website.git
cd the-cix-project-website
./deploy/install-vm.sh --domain=cixproject.org
```

The installer installs Caddy if necessary, creates the bare mirror under
`/srv/the-cix-project-website.git`, serves validated releases from
`/srv/the-cix-project-site`, and installs the updater and timer.

## Operate

```sh
python3 scripts/check-site.py
systemctl start the-cix-project-website-update.service
systemctl status the-cix-project-website-update.timer
curl --fail https://cixproject.org/
curl --fail https://www.cixproject.org/
```

The updater leaves the existing `current` release live if a fetched commit
fails validation.
