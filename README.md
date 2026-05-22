# Gerrit Autosubmit

Gerrit Autosubmit is a very simple program which does the following:

1. Fetch all submittable changes via the Gerrit API
2. Filter changes to those with an active "Submit" button
3. Filter out changes that would submit ancestors **not** marked with the
   `Autosubmit` label
4. Submit the longest chain
5. Repeat every 30 seconds

> [!NOTE]
> ALL changes in a chain must have the `Autosubmit` label set to be
> automatically submitted.

## Credits

Based on
[mschwaig/snix](https://github.com/mschwaig/snix/tree/8903fbb9752edfee02499319ea61a6f291eff608/ops/gerrit-autosubmit).
This fork adds code improvements, a [Nix flake](./flake.nix), and
[NixOS module](./nix/module.nix) outputs.

## Usage

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

Make sure the autosubmit-bot user has a HTTP password set!

An admin group or similar will need the following permissions:

- Label Autosubmit 0 +1

I recommend doing this with a special group called "Autosubmit" too so you can
more easily scope the permissions.

Import the module and use it:

```nix
{
  imports = [ inputs.gerrit-autosubmit.nixosModules.default ];

  services.gerrit-autosubmit = {
    enable = true;
    gerritUrl = "https://gerrit.example.com";
    gerritUsername = "autosubmit-bot";
    secretsFile = config.age.secrets.gerritAutosubmitEnvironment.path;
  };
}
```

The contents of the secret file should be in this format:

```env
GERRIT_PASSWORD=xxxxxxx
```

For a complete usage example see my
[Gerrit module](https://git.plumj.am/PlumJam/nixos/src/commit/8e727019c252ac3166bdfaac373dde3b7f549d8e/modules/gerrit.nix).

## Contributing

I'll gladly accept contributions. Please open a PR or an issue on GitHub.

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
