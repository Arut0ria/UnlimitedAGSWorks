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

        # Fonction pour surveiller et exécuter
        monitor_changes() {
          if ! command -v inotifywait &> /dev/null; then
              echo "Error: inotifywait is not installed. Ensure it's in your buildInputs."
              return 1
          fi

          echo "Monitoring changes in $WATCH_DIR. Press Ctrl+C to stop."

          # Fonction pour arrêter le processus existant
          stop_previous_process() {
            if [ $AGS_PID -ne 0 ]; then
              echo "Stopping previous process with PID $AGS_PID"
              kill $AGS_PID 2>/dev/null || true
              wait $AGS_PID 2>/dev/null || true
              AGS_PID=0
            fi
          }

          # Lancer la commande pour la première fois
          echo "Running initial command: $RUN_COMMAND"
          $RUN_COMMAND &
          AGS_PID=$!

          # Boucle pour surveiller les changements
          while true; do
              inotifywait -e modify,create,delete -r "$WATCH_DIR" --exclude '(\.git|node_modules|\.swp|\.tmp)' && \
              echo "Change detected, restarting command: $RUN_COMMAND" && \
              stop_previous_process && \
              $RUN_COMMAND &
              AGS_PID=$!
          done
        }
      '';
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
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          # includes astal3 astal4 astal-io by default
          (ags.packages.${system}.default.override {
            extraPackages = [
              # cherry pick packages
            ];
          })
          pkgs.inotify-tools
        ];

        shellHook = ''
          ${watchDir}
        '';
      };
    };
}
