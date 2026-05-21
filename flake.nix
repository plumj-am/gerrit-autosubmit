{
  description = "Gerrit Autosubmit";

  nixConfig = {
    builders-use-substitutes = true;
    flake-registry = "";
    show-trace = true;

    experimental-features = [
      "flakes"
      "nix-command"
      "pipe-operators"
    ];

    extra-substituters = [
      "https://cache.garnix.io/"
      "https://nix-community.cachix.org/"
    ];

    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    fenix.url = "github:nix-community/fenix";
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      flake-utils,
      advisory-db,
      fenix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        inherit (pkgs) lib;

        craneLib = (crane.mkLib pkgs).overrideToolchain fenix.packages.${system}.complete.toolchain;

        src = craneLib.cleanCargoSource ./.;

        commonArgs = {
          inherit src;
          strictDeps = true;
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        default = craneLib.buildPackage {
          pname = "gerrit-autosubmit";

          src = ./..;
        };
      in
      {
        checks = lib.mapAttrs' (n: v: lib.nameValuePair "package-${n}" v) self.packages.${system} // {

          rust-clippy = craneLib.cargoClippy (
            commonArgs
            // {
              inherit cargoArtifacts;

              src = ./.;

              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );

          rust-doc = craneLib.cargoDoc (
            commonArgs
            // {
              inherit cargoArtifacts;

              src = ./.;

              env.RUSTDOCFLAGS = "--deny warnings";
            }
          );

          rust-fmt = craneLib.cargoFmt {
            inherit cargoArtifacts;

            src = ./.;

            rustFmtExtraArgs = "--config-path ${./.rustfmt.toml}";
          };

          toml-fmt = craneLib.taploFmt {
            inherit cargoArtifacts;

            src = lib.sources.sourceFilesBySuffices src [ ".toml" ];

            taploExtraArgs = "--config ${./.taplo.toml}";
          };

          rust-audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };
        };

        packages = {
          inherit default;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = default;
        };

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};
        };
      }
    );
}
