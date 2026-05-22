# Gerrit Autosubmit

Automatically submit chains of labelled changes from longest to shortest at an
adjustable interval.

## Overview

1. Fetch all submittable changes via the Gerrit API
2. Filter changes to those with an active "Submit" button
3. Filter out changes that would submit ancestors **not** marked with the
   `Autosubmit` label
4. Submit the longest chain
5. If a submission occurred immediately loop again
6. Otherwise, repeat every 30 seconds (configurable)

> [!NOTE]
> As mentioned in step 3, ALL changes in a chain must have the `Autosubmit`
> label set to be automatically submitted.

## Prerequisites

You will need an "Autosubmit" label with the following configuration:

```config
[label "Autosubmit"]
  function = NoOp
  value = 0 No
  value = +1 Yes
  defaultValue = 0
```

You will also need an "autosubmit-bot" user with the following permissions:

- Submit
- Read access for the necessary repository

> [!IMPORTANT]
> Make sure the autosubmit-bot user has a HTTP password set!

Another group, such as `Administrators`, will need the following permissions to
label changes for automatic submission:

- Label Autosubmit 0 +1

I recommend doing this with a new group called "Autosubmit" too so you can
easily scope the permissions.

## Usage

### NixOS

Add to your flake inputs:

```nix
{
  inputs.gerrit-autosubmit = {
    url = "git+https://git.plumj.am/plumjam/gerrit-autosubmit";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Import the module and use it:

```nix
{
  imports = [ inputs.gerrit-autosubmit.nixosModules.default ];

  services.gerrit-autosubmit = {
    enable = true;
    gerritUrl = "https://gerrit.example.com";
    gerritUsername = "autosubmit-bot";
    interval = 30;
    secretsFile = config.age.secrets.gerritAutosubmitEnvironment.path;
  };
}
```

Available options:

| Key              | Default                      | Description                               |
| ---------------- | ---------------------------- | ----------------------------------------- |
| `enable`         | `false`                      | Enable the service                        |
| `gerritUrl`      | `https://gerrit.example.com` | Gerrit base URL                           |
| `gerritUsername` | `autosubmit-bot`             | Gerrit bot user                           |
| `interval`       | `30`                         | Poll interval in seconds                  |
| `secretsFile`    | `config.age.secretsDir`      | Path to the environment file with secrets |

The secrets file must contain the password in this format:

```env
GERRIT_PASSWORD=xxxxxxx
```

For a complete usage example see my
[Gerrit module](https://git.plumj.am/PlumJam/nixos/src/commit/8e727019c252ac3166bdfaac373dde3b7f549d8e/modules/gerrit.nix).

### Cargo (systemd service)

Install from [crates.io](https://crates.io/crates/gerrit-autosubmit):

```bash
cargo install gerrit-autosubmit
```

Or build from source:

```bash
git clone https://git.plumj.am/plumjam/gerrit-autosubmit
cd gerrit-autosubmit
cargo build --release
```

The binary is at `./target/release/gerrit-autosubmit`.

Example systemd service unit (`/etc/systemd/system/gerrit-autosubmit.service`):

```ini
[Unit]
Description=gerrit-autosubmit – autosubmit bot for Gerrit
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gerrit-autosubmit
Restart=always
DynamicUser=true
EnvironmentFile=/etc/gerrit-autosubmit/env

[Install]
WantedBy=multi-user.target
```

Create the environment file (`/etc/gerrit-autosubmit/env`):

Available options:

| Key                         | Type                   | Description                        |
| --------------------------- | ---------------------- | ---------------------------------- |
| `GERRIT_URL`                | required               | Gerrit base URL, no trailing slash |
| `GERRIT_USERNAME`           | required               | Gerrit bot user                    |
| `GERRIT_PASSWORD`           | required               | HTTP password for bot user         |
| `GERRIT_POLL_INTERVAL_SECS` | optional, default `30` | Seconds between poll cycles        |

```env
GERRIT_URL=https://gerrit.example.com
GERRIT_USERNAME=autosubmit-bot
GERRIT_PASSWORD=xxxxxxx
GERRIT_POLL_INTERVAL_SECS=30
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now gerrit-autosubmit
```

## Contributing

I'll gladly accept contributions. Please open a PR or an issue on GitHub.

## Credits

Initially based on
[mschwaig/snix/gerrit-autosubmit](https://github.com/mschwaig/snix/tree/8903fbb9752edfee02499319ea61a6f291eff608/ops/gerrit-autosubmit).

Some changes include:

- no system dependencies (pure Rust)
- improved error handling
- more configuration options
- a [Nix flake](./flake.nix) and [NixOS module](./nix/module.nix) outputs

## License

```
The MIT License (MIT)

Copyright (c) 2019 Vincent Ambo
Copyright (c) 2020-2024 The TVL Authors
Copyright (c) 2025 The Snix Project
Copyright (c) 2026-present PlumJam <git@plumj.am>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
