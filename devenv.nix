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
    hadolint = {
      enable = true;
      # Ignore package manager detections
      entry = "hadolint --ignore DL3008 --ignore DL3015";
    };
    shellcheck.enable = true;
  };
}
