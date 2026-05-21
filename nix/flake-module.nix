{ self, inputs, ... }:

let
  inherit (inputs) nixpkgs crane fenix advisory-db;

  # Repo root relative paths (this file is in nix/)
  root = ./..;
in
{
  perSystem = { system, ... }:
    let
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs) lib;

      craneLib = (crane.mkLib pkgs).overrideToolchain fenix.packages.${system}.complete.toolchain;

      src = craneLib.cleanCargoSource root;

      commonArgs = {
        inherit src;
        strictDeps = true;
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      pkg = craneLib.buildPackage (
        commonArgs
        // {
          pname = "gerrit-autosubmit";
        }
      );
    in
    {
      packages = {
        default = pkg;
        gerrit-autosubmit = pkg;
      };

      checks = {
        build = pkg;

        rust-clippy = craneLib.cargoClippy (
          commonArgs
          // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          }
        );

        rust-doc = craneLib.cargoDoc (
          commonArgs
          // {
            inherit cargoArtifacts;
            env.RUSTDOCFLAGS = "--deny warnings";
          }
        );

        rust-fmt = craneLib.cargoFmt {
          inherit cargoArtifacts;
          rustFmtExtraArgs = "--config-path ${root}/.rustfmt.toml";
        };

        toml-fmt = craneLib.taploFmt {
          inherit cargoArtifacts;
          src = lib.sources.sourceFilesBySuffices src [ ".toml" ];
          taploExtraArgs = "--config ${root}/.taplo.toml";
        };

        rust-audit = craneLib.cargoAudit {
          inherit src advisory-db;
        };
      };

      apps.default = {
        type = "app";
        program = "${pkg}/bin/gerrit-autosubmit";
      };

      devShells.default = craneLib.devShell {
        checks = self.checks.${system};
      };
    };

  flake = {
    nixosModules.default = import ./module.nix;

    overlays.default = final: prev: {
      gerrit-autosubmit = self.packages.${final.system}.default;
    };

    # flake-parts module for consumers:
    #   imports = [ inputs.gerrit-autosubmit.flakeModules.default ];
    flakeModules.default = { inputs, ... }: {
      perSystem = { system, ... }: {
        packages.gerrit-autosubmit = inputs.gerrit-autosubmit.packages.${system}.default;
      };
      flake = {
        nixosModules.gerrit-autosubmit = import ./module.nix;
        overlays.gerrit-autosubmit = final: prev: {
          gerrit-autosubmit = inputs.gerrit-autosubmit.packages.${final.system}.default;
        };
      };
    };
  };
}
