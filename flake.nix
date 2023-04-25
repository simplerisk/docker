{
  description = "Docker repository";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-22.11";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) mkShell writeShellScript docker-compose dockle;

      in {
        apps = {
          "lint" = {
            type = "app";
            program = "${dockle}/bin/dockle";
          };
          "docker-compose" = {
            type = "app";
            program = "${docker-compose}/bin/docker-compose";
          };
          "generate-stack" = {
            type = "app";
            program = toString (writeShellScript "generate_stack.sh" (builtins.readFile ./generate_stack.sh));
          };
          "generate-simplerisk-dockerfile" = {
            type = "app";
            program = toString (writeShellScript "generate_dockerfile.sh" (builtins.readFile ./simplerisk/generate_dockerfile.sh));
          };
          "generate-simplerisk-minimal-dockerfile" = {
            type = "app";
            program = toString (writeShellScript "generate_dockerfile.sh" (builtins.readFile ./simplerisk-minimal/generate_dockerfile.sh));
          };
        };
        devShells.default = mkShell { buildInputs = [ docker-compose dockle ]; };
      }
    );
}
