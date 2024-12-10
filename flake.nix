{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    ags.url = "github:aylur/ags";
  };

  outputs = { self, nixpkgs, ags }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      directoryToWatch = ".";
      mainFile = "app.ts";

      watchDir = ''
        WATCH_DIR="${directoryToWatch}"
        RUN_COMMAND="ags run ${mainFile}"

        start_ags() {
          $RUN_COMMAND & AGS_PID=$!
        }

        stop_ags() {
          if [ ! -z "$AGS_PID" ]; then
            pkill -P $AGS_PID
          fi
        }

        run_watch() {
          start_ags
          inotifywait -m -r -e create,modify,delete . | while read events; do
            stop_ags && start_ags
          done
        }
      '';

      libraries = with ags.packages.${system}; [
        cava
        apps
      ];
    in
    {
      packages.${system}.default = ags.lib.bundle {
        inherit pkgs;
        src = ./.;
        name = "unlimited-shell"; # name of executable
        entry = "${mainFile}";

        # additional libraries and executables to add to gjs' runtime
        extraPackages = [
          # ags.packages.${system}.battery
          # pkgs.fzf
        ] ++ libraries;
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          # includes astal3 astal4 astal-io by default
          (ags.packages.${system}.default.override {
            extraPackages = [
              # cherry pick packages
            ] ++ libraries;
          })
          pkgs.inotify-tools
        ];

        shellHook = ''
          ${watchDir}
        '';
      };
    };
}
