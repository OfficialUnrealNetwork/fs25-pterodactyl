# Farming Simulator 25 Pterodactyl Egg

A GitHub-hosted Pterodactyl egg and GHCR Docker image for running the Windows Farming Simulator 25 dedicated server under Wine with a browser-based noVNC desktop.

This repository does **not** include Farming Simulator 25, DLC, product keys, or dedicated-server licenses. Supply legally obtained files from your GIANTS account.

## Automatic GitHub setup

Every push to `main` runs GitHub Actions. The workflow:

1. Builds the Docker image in `docker/`.
2. Publishes it to `ghcr.io/OWNER/REPOSITORY:latest`.
3. Generates `egg-farming-simulator-25.json` with that exact image address.
4. Commits the generated egg JSON back to the repository.

The egg therefore works whether this repository is under a personal account or an organization.

## Create the repository

1. Create a new **public** GitHub repository named `fs25-pterodactyl`.
2. Upload every file and folder from this package to the repository root.
3. Make sure the default branch is named `main`.
4. Open the repository's **Actions** tab and run **Build FS25 Pterodactyl image**, or make a small commit to trigger it.
5. Wait for the workflow to finish successfully.

The workflow uses GitHub's built-in `GITHUB_TOKEN`; no personal access token or repository secret is required.

## Make the GHCR image public

After the first successful workflow:

1. Open the repository's package from the **Packages** section.
2. Open **Package settings**.
3. Change the package visibility to **Public**.

Public GHCR images can be pulled by Pterodactyl Wings without registry credentials.

## Download the egg from GitHub

The generated file is available at:

```text
https://raw.githubusercontent.com/OWNER/REPOSITORY/main/egg-farming-simulator-25.json
```

Example for `OfficialUnrealNetwork/fs25-pterodactyl`:

```text
https://raw.githubusercontent.com/OfficialUnrealNetwork/fs25-pterodactyl/main/egg-farming-simulator-25.json
```

Pterodactyl normally imports an egg from a local JSON file. Download the raw file first:

```bash
curl -L \
  https://raw.githubusercontent.com/OfficialUnrealNetwork/fs25-pterodactyl/main/egg-farming-simulator-25.json \
  -o egg-farming-simulator-25.json
```

Then import it from **Admin Panel → Nests → Import Egg**.

## Updating

Edit the Docker or egg template files and push the change to `main`. GitHub Actions rebuilds and republishes `:latest`. Wings will pull the image when Pterodactyl requests an image pull or when a server is recreated. Restarting a server alone may continue using the locally cached image.

## Required Pterodactyl allocations

| Port | Protocol | Purpose |
|---|---|---|
| `10823` | TCP and UDP | FS25 game traffic and primary allocation |
| `6080` | TCP | Browser noVNC desktop |
| `7999` | TCP | FS25 web administration |
| `5900` | TCP | Optional direct VNC |

## First installation

1. Create the Pterodactyl server with `AUTO_INSTALL=true` and `AUTOSTART_SERVER=false`.
2. Upload the GIANTS Windows ESD image to `/home/container/installer`.
3. Start the server.
4. Open `http://NODE-IP:6080/vnc.html?resize=remote&autoconnect=1`.
5. Complete installation and dedicated-server license activation.
6. Set `AUTOSTART_SERVER=true` and restart.
7. Use port `7999` for the Farming Simulator web administration page.

## Files

- `egg-farming-simulator-25.json` — generated importable egg.
- `egg/egg-farming-simulator-25.template.json` — source egg template.
- `docker/Dockerfile` — FS25 Wine/noVNC Pterodactyl image.
- `docker/ptero-entrypoint.sh` — container entrypoint.
- `docker/ptero-start.sh` — FS25 startup wrapper.
- `.github/workflows/build-image.yml` — builds and publishes the GHCR image.
- `scripts/render-egg.py` — safely inserts the GHCR image into the egg.

## Important limitation

GitHub hosts the repository and Docker image. The licensed FS25 installer and activated server files remain in the Pterodactyl server volume; they must not be placed in a public GitHub repository or public container image.
