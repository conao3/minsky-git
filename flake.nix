{
  description = "A two-counter Minsky machine that runs on git fetch refspecs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem =
        { pkgs, ... }:
        {
          packages.default =
            (pkgs.writeShellApplication {
              name = "git-minsky";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.git
              ];
              text = builtins.readFile ./bin/git-minsky;
            }).overrideAttrs
              {
                meta = {
                  description = "A two-counter Minsky machine that runs on git fetch refspecs";
                  homepage = "https://github.com/conao3/bash-git-minsky";
                  license = pkgs.lib.licenses.asl20;
                  mainProgram = "git-minsky";
                  platforms = pkgs.lib.platforms.unix;
                };
              };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              bashInteractive
              git
              gnumake
              nixfmt
              shellcheck
              shfmt
            ];
          };

          treefmt.programs = {
            nixfmt.enable = true;
            shfmt.enable = true;
          };
        };
    };
}
