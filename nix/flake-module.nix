{ self, inputs, ... }:

let
  inherit (inputs)
    nixpkgs
    crane
    fenix
    ;

  root = ./..;
in
{
  perSystem =
    { system, ... }:
    let
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs) lib;

      pname = "gerrit-autosubmit";

      craneLib = (crane.mkLib pkgs).overrideToolchain fenix.packages.${system}.complete.toolchain;

      src = craneLib.cleanCargoSource root;

      commonArgs = {
        inherit src;
        strictDeps = true;
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      gerrit-autosubmit = craneLib.buildPackage (
        commonArgs
        // {
          inherit pname;
          meta.mainProgram = "gerrit-autosubmit";
        }
      );
    in
    {
      packages = {
        inherit gerrit-autosubmit;
        default = gerrit-autosubmit;
      };

      checks = {
        "package-${pname}" = gerrit-autosubmit;

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
          inherit cargoArtifacts src;
          rustFmtExtraArgs = "--config-path ${root}/.rustfmt.toml";
        };

        toml-fmt = craneLib.taploFmt {
          inherit cargoArtifacts;
          src = lib.sources.sourceFilesBySuffices src [ ".toml" ];
          taploExtraArgs = "--config ${root}/.taplo.toml";
        };
      };

      devShells.default = craneLib.devShell {
        checks = self.checks.${system};
      };
    };

  flake = {
    nixosModules.default = {
      imports = [ ./module.nix ];
      nixpkgs.overlays = [ self.overlays.default ];
    };

    overlays.default = final: _: {
      gerrit-autosubmit = self.packages.${final.system}.default;
    };

    # flake-parts module for consumers:
    #   imports = [ inputs.gerrit-autosubmit.flakeModules.default ];
    flakeModules.default =
      { inputs, ... }:
      {
        perSystem =
          { system, ... }:
          {
            packages.gerrit-autosubmit = inputs.gerrit-autosubmit.packages.${system}.default;
          };
        flake = {
          nixosModules.gerrit-autosubmit = import ./module.nix;
          overlays.gerrit-autosubmit = final: _: {
            gerrit-autosubmit = inputs.gerrit-autosubmit.packages.${final.system}.default;
          };
        };
      };
  };
}
