let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};
in
pkgs.mkShell {
  name = "scripts-shell";
  buildInputs = with pkgs; [
    chart-testing
    ginkgo
    git
    go_1_20
    golint
    kubectl
    kubernetes-helm
    gnumake
    minikube
    semver-tool
    yq-go
    which
    curl
    cacert
    util-linux
    jq
    zfs
  ] ++ pkgs.lib.optional (builtins.getEnv "IN_NIX_SHELL" == "pure") [ docker ];
  shellHook = ''
    export GOPATH=$(pwd)/nix/.go
    export GOCACHE=$(pwd)/nix/.go/cache
    export TMPDIR=$(pwd)/nix/.tmp
    export PATH=$GOPATH/bin:$PATH
    mkdir -p "$TMPDIR"

    if [ "$IN_NIX_SHELL" = "pure" ]; then
      # working sudo within a pure nix-shell
      for sudo in /run/wrappers/bin/sudo /usr/bin/sudo /usr/local/bin/sudo /sbin/sudo /bin/sudo; do
        mkdir -p $(pwd)/nix/bins
        ln -sf $sudo $(pwd)/nix/bins/sudo
        export PATH=$(pwd)/nix/bins:$PATH
        break
      done
    else
      rm $(pwd)/nix/bins/sudo 2>/dev/null || :
      rmdir $(pwd)/nix/bins 2>/dev/null || :
    fi
  '';
}
