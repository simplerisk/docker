{
  description = "Docker repository";

  inputs = {
    devshell.url = "github:numtide/devshell";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, devshell, utils, nixpkgs }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlays.default ];
        };

        inherit (builtins) readFile;
        inherit (pkgs) writeShellScript docker-compose dockle;
        inherit (pkgs.devshell) mkShell importTOML;

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
            program = toString (writeShellScript "generate_stack.sh" (readFile ./generate_stack.sh));
          };
          "generate-simplerisk-dockerfile" = {
            type = "app";
            program = toString (writeShellScript "generate_dockerfile.sh" (readFile ./simplerisk/generate_dockerfile.sh));
          };
          "generate-simplerisk-minimal-dockerfile" = {
            type = "app";
            program = toString (writeShellScript "generate_dockerfile.sh" (readFile ./simplerisk-minimal/generate_dockerfile.sh));
          };
        };
        devShells.default = mkShell { imports = [ (importTOML ./devshell.toml) ]; };
      }
    );
}
