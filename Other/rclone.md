# rclone Integration

Hog uses [rclone](https://rclone.org/) as an alternative to EOS for storing IP generated products and official bitstream files on any cloud or remote storage backend (S3, Dropbox, SFTP, Google Drive, etc.).

## Two Uses

### 1. IP Products

Controlled by the `HOG_IP_PATH` CI variable and implemented in `Tcl/hog.tcl` (`HandleIP` procedure).

Hog recognises an rclone path by the `<remote>:<path>` pattern (e.g. `dropbox:MyProject/IPs`). When detected:

- **push** — tars the IP generated files into `<xci_name>_<md5hash>.tar` and uploads it with `rclone copyto`. If an archive with the same hash already exists on the remote it is skipped (content-addressed, no duplicates).
- **pull** — checks the remote with `rclone ls`, then downloads the archive with `rclone copyto`.

### 2. Bitstream and Bin Files

Controlled by the `HOG_OFFICIAL_BIN_PATH` CI variable and implemented in the `hog-bin` job in `YAML/hog-main.yml`. Runs only on version tags (`v*`).

If `HOG_OFFICIAL_BIN_PATH` starts with `<remote>:`, Hog:

1. Creates the destination folder: `rclone mkdir ${BIN_PATH}/${CI_COMMIT_TAG}`
2. Copies the entire `bin/` directory: `rclone copy bin ${BIN_PATH}/${CI_COMMIT_TAG}`
3. Optionally copies Doxygen docs: `rclone copy Doc/html ${BIN_PATH}/Doc` (when `HOG_USE_DOXYGEN=1`)

## Configuration

Hog passes `--config <path>` to every rclone call. The path is resolved as follows:

| Condition | Config used |
|---|---|
| `HOG_RCLONE_CONFIG` is set and points to a file | That file |
| `HOG_RCLONE_CONFIG` is unset | `/dev/null` — rclone falls back to environment variables |

### Option A — Config file (`HOG_RCLONE_CONFIG`)

Generate a config file with `rclone config`, then point Hog to it:

```bash
# In your CI variables or shell environment
export HOG_RCLONE_CONFIG=/path/to/rclone.conf
```

The file looks like:

```ini
[mybucket]
type = s3
provider = AWS
access_key_id = AKIAIOSFODNN7EXAMPLE
secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
region = eu-west-1
```

Then set the Hog path variables to use that remote:

```
HOG_IP_PATH          = mybucket:firmware/ips
HOG_OFFICIAL_BIN_PATH = mybucket:firmware/releases
```

### Option B — Environment variables only (no config file)

When `HOG_RCLONE_CONFIG` is not set, Hog passes `--config /dev/null` to rclone. In this mode rclone reads the entire remote configuration from environment variables using the naming convention:

```
RCLONE_CONFIG_<REMOTE>_TYPE=<backend>
RCLONE_CONFIG_<REMOTE>_<OPTION>=<value>
```

`<REMOTE>` must be uppercase and match the remote name used in `HOG_IP_PATH` / `HOG_OFFICIAL_BIN_PATH`.

#### S3 (AWS or compatible)

```bash
export HOG_IP_PATH=mys3:firmware/ips

export RCLONE_CONFIG_MYS3_TYPE=s3
export RCLONE_CONFIG_MYS3_PROVIDER=AWS
export RCLONE_CONFIG_MYS3_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export RCLONE_CONFIG_MYS3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export RCLONE_CONFIG_MYS3_REGION=eu-west-1
```

#### Dropbox

```bash
export HOG_OFFICIAL_BIN_PATH=mybox:firmware/releases

export RCLONE_CONFIG_MYBOX_TYPE=dropbox
export RCLONE_CONFIG_MYBOX_TOKEN='{"access_token":"sl.XXXXXXX","token_type":"bearer",...}'
```

#### SFTP

```bash
export HOG_IP_PATH=mysftp:firmware/ips

export RCLONE_CONFIG_MYSFTP_TYPE=sftp
export RCLONE_CONFIG_MYSFTP_HOST=myserver.example.com
export RCLONE_CONFIG_MYSFTP_USER=hog
export RCLONE_CONFIG_MYSFTP_KEY_PEM="$(cat ~/.ssh/id_ed25519)"
```

#### WebDAV — CERNBox / EOS

CERNBox exposes EOS via WebDAV at `https://cernbox.cern.ch/cernbox/webdav/`. Use `vendor = owncloud` because CERNBox is built on ownCloud.

The password must be obscured with `rclone obscure <your-password>` before use (this is required by rclone's webdav backend even when set via env vars).

```bash
export HOG_IP_PATH=cernbox:eos/user/d/doe/firmware/ips

export RCLONE_CONFIG_CERNBOX_TYPE=webdav
export RCLONE_CONFIG_CERNBOX_URL=https://cernbox.cern.ch/cernbox/webdav/
export RCLONE_CONFIG_CERNBOX_VENDOR=owncloud
export RCLONE_CONFIG_CERNBOX_USER=doe
export RCLONE_CONFIG_CERNBOX_PASS=$(rclone obscure "$CERN_PASSWORD")
```

Path structure on CERNBox WebDAV:

| Space | Path prefix |
|---|---|
| Personal (home) | `cernbox:eos/user/<initial>/<username>/...` |
| Project space | `cernbox:eos/project/<initial>/<project>/...` |

> In a CI pipeline, store the CERN password as a masked variable (e.g. `CERN_PASSWORD`) and compute `HOG_RCLONE_CONFIG_CERNBOX_PASS` at job start with `rclone obscure`.

#### Google Drive

```bash
export HOG_OFFICIAL_BIN_PATH=mygdrive:firmware/releases

export RCLONE_CONFIG_MYGDRIVE_TYPE=drive
export RCLONE_CONFIG_MYGDRIVE_CLIENT_ID=XXXX.apps.googleusercontent.com
export RCLONE_CONFIG_MYGDRIVE_CLIENT_SECRET=XXXX
export RCLONE_CONFIG_MYGDRIVE_TOKEN='{"access_token":"ya29.XXXX","refresh_token":"1//XXXX",...}'
export RCLONE_CONFIG_MYGDRIVE_ROOT_FOLDER_ID=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs
```

> The env-variable approach is well suited for CI/CD pipelines where secrets are injected as masked variables and no config file is checked into the repository.

## Summary of CI Variables

| Variable | Description |
|---|---|
| `HOG_IP_PATH` | Remote path for IP generated products (e.g. `mys3:project/ips`). |
| `HOG_OFFICIAL_BIN_PATH` | Remote path for official bitstream releases (e.g. `mys3:project/releases`). |
| `HOG_RCLONE_CONFIG` | Path to an rclone config file. Leave unset to use env-variable-based auth. |
