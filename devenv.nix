{ pkgs
, ...
}:

let
  inherit (pkgs) docker-compose dockle grype;

in {
  packages = [
    docker-compose
    dockle
    grype
  ];

  # https://devenv.sh/pre-commit-hooks/
  pre-commit.hooks = {
    hadolint.enable = true;
    shellcheck.enable = true;
  };
}
