{ pkgs, lib, stdenv ? pkgs.stdenvNoCC, extraNativeBuildInputs ? [ ], ... }:
# mkDevShell is closely based on the structure of mkShell
# * https://stackoverflow.com/a/71112117/3486684
{
# ===========================================
# mkShell Attributes:
# https://nixos.org/manual/nixpkgs/unstable/#sec-pkgs-mkShell-attributes
# ===========================================.
packages ? [ ], inputsFrom ? [ ], phases ? [ "buildPhase" "installPhase" ], name
, meta, shellInitialization, shellCleanUp, ... }@inputAttrs:
let
  # deduplicates builtInputs across: 1) any corresponding buildInputs in
  # inputAttrs (the inputs to this `mkDevShell` function), 2) all the
  # derivations listed in `inputsFrom`, and 3) all the corresponding buildInputs
  # of these derivations.
  mergeBuildInputs = inputs:
    # check if there is an attribute with the same name as `focusSet` in this
    # `mkDevShell's` input attributes; if so, get it, otherwise begin with the
    # empty list
    (inputAttrs.${inputs} or [ ]) ++ (
      # lib.subtractLists: subtracts first list from second
      # https://nixos.org/manual/nixpkgs/unstable/
      lib.subtractLists
      # first list is a list of derivations whose build inputs will be included
      # in the final dev shell's environment.
      inputsFrom (
        # flattens nested lists into an un-nested one
        lib.flatten
        # remove all buildInputs that are already listed in inputsFrom
        (lib.catAttrs inputs inputsFrom)));

  unmodifiedAttrs = builtins.removeAttrs inputAttrs
    # These are the attributes that we will override/merge from `inputAttrs`.
    [
      "name"
      "packages"
      "inputsFrom"
      "buildInputs"
      "nativeBuildInputs"
      "propagatedBuildInputs"
      "propagatedNativeBuildInputs"
      "shellHook"
    ];
  shellInitScript = "${name}-shell-init";
  shellInvokeScript = "${name}-shell";
  shellCleanScript = "${name}-shell-clean";

  # Minimal stdenv based on: https://github.com/viperML/mkshell-minimal
  miniStdEnv = let
    mergedExtraNativeBuildInputs = [ pkgs.sd ]
      ++ lib.subtractLists [ pkgs.sd ] extraNativeBuildInputs;
  in stdenv.override {
    extraNativeBuildInputs = mergedExtraNativeBuildInputs;
    cc = null;
    preHook = "";
    allowedRequisites = null;
    initialPath = [ pkgs.coreutils ];
    shell = pkgs.lib.getExe pkgs.bash;
  };
  IN_NIX_SHELL = "impure"; # these custom shells are impure by construction
in miniStdEnv.mkDerivation ({
  inherit name meta phases IN_NIX_SHELL;

  buildInputs = mergeBuildInputs "buildInputs";
  nativeBuildInputs = packages ++ (mergeBuildInputs "nativeBuildInputs");
  propagatedBuildInputs = mergeBuildInputs "propagatedBuildInputs";
  propagatedNativeBuildInputs = mergeBuildInputs "propagatedNativeBuildInputs";
  preferLocalBuild = true;

  buildPhase = let
    # a concatenation of the various shell hookzs that are required by the
    # buildInputs that go into making up the shell environment
    shellHooks = lib.concatStringsSep "\n"
      (lib.catAttrs "shellHook" (lib.reverseList inputsFrom ++ [ inputAttrs ]));
    shellInitBody = ''
      # shell hooks concatenated from build inputs for this shell
      ${shellHooks}
      # make cargo home directory, sccache directory, and config.toml
      ${shellInitialization}
    '';
    exportFixes = import ./exportFixes.nix {
      inherit lib;
      shellInit = shellInitScript;
    };
    startShell = ''
      #!/usr/bin/env zsh
      source $out/bin/${shellInitScript} ; zsh -i
    '';
  in ''
    runHook preBuild
    echo "exporting vars to shellInit"
    export >> ${shellInitScript}
    ${exportFixes}

    echo "${shellInitBody}" >> ${shellInitScript}
    echo "${startShell}" >> ${shellInvokeScript}
    echo "${shellCleanUp}" >> ${shellCleanScript}
    echo

    runHook postBuild
  '';

  installPhase = let
    export_dev_env = ./export-dev-env;
    export_nix_env = ./export-nix-env;
  in ''
    runHook preInstall
    # echo "PWD: $PWD" echo "out: $out" echo "ls: $(ls)"
    install -m 755 -D --target-directory $out/bin $PWD/${shellInitScript}
    install -m 755 -D --target-directory $out/bin $PWD/${shellInvokeScript}
    install -m 755 -D --target-directory $out/bin $PWD/${shellCleanScript}
    install -m 755 -D -T ${export_dev_env} $out/bin/${name}-export-dev-env
    install -m 755 -D -T ${export_nix_env} $out/bin/${name}-export-nix-env
    runHook postInstall
  '';

} // unmodifiedAttrs)
