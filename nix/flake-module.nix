{ self, inputs, ... }:

let
  inherit (inputs)
    nixpkgs
    crane
    fenix
    advisory-db
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
        buildInputs = [ pkgs.openssl ];
        nativeBuildInputs = [ pkgs.pkg-config ];
        env.LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib";

      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      gerrit-autosubmit = craneLib.buildPackage (
        commonArgs
        // {
          inherit pname;
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

        rust-audit = craneLib.cargoAudit {
          inherit src advisory-db;
        };
      };

      devShells.default = craneLib.devShell {
        checks = self.checks.${system};
        env.LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib";
      };
    };

  flake = {
    nixosModules.default = import ./module.nix;

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
