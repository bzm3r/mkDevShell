{ lib, buildEnv, stdenv, writeTextFile }:
# mkDevShell is closely based on the structure of mkShell
# * https://stackoverflow.com/a/71112117/3486684
{
# ===========================================
# mkShell Attributes:
# https://nixos.org/manual/nixpkgs/unstable/#sec-pkgs-mkShell-attributes
# ===========================================
#
# List of executable packages to add to the nix-shell environment.
packages ? [ ]
  #
  # -----------------------
  #
  # Add build dependencies of the listed derivations to the nix-shell environment.
, inputsFrom ? [ ]
  #
  # -----------------------
  # Bash statements that are executed by nix-shell.
  #, shellHook ? ""
  # -----------------------
  # ===========================================
  # The following are attributes inherited by mkShell from mkDerivation
  # ===========================================
  #
  # Set the name of the derivation. (Not optional)
, name, meta, shellInitialization, ... }@inputAttrs:
let
  # deduplicates builtInputs across: 1) any corresponding buildInputs in
  # inputAttrs (the inputs to this `mkDevShell` function), 2) all the
  # derivations listed in `inputsFrom`, and 3) all the corresponding buildInputs
  # of these derivations.
  mergeBuildInputs = buildInputs:
    # check if there is an attribute with the same name as `focusSet` in this
    # `mkDevShell's` input attributes; if so, get it, otherwise begin with the
    # empty list
    (inputAttrs.${buildInputs} or [ ]) ++ (
      # lib.subtractLists: subtracts first list from second
      # https://nixos.org/manual/nixpkgs/unstable/
      lib.subtractLists
      # first list is a list derivations whose build inputs will be included
      # in the final dev shell's environment.
      inputsFrom (
        # flattens nested lists into an un-nested one
        lib.flatten
        # remove all buildInputs that are already listed in inputsFrom
        (lib.catAttrs buildInputs inputsFrom)));

  # remove from `attrs` the listed attributes, because they are not required for
  # use of the shell.
  overridingAttrs = builtins.removeAttrs inputAttrs [
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
in stdenv.mkDerivation ({
  inherit name meta;
  buildInputs = mergeBuildInputs "buildInputs";
  nativeBuildInputs = packages ++ (mergeBuildInputs "nativeBuildInputs");
  propagatedBuildInputs = mergeBuildInputs "propagatedBuildInputs";
  propagatedNativeBuildInputs = mergeBuildInputs "propagatedNativeBuildInputs";
  preferLocalBuild = true;

  buildPhase = let
    # a concatenation of the various shell hookzs that are required by
    # the buildInputs that go into making up the shell environment
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
      source $out/${shellInitScript} ; zsh -i
    '';
  in ''
    runHook preBuild
    echo "exporting vars to shellInit"
    export >> ${shellInitScript}
    ${exportFixes}

    echo "${shellInitBody}" >> ${shellInitScript}
    echo "${startShell}" >> ${shellInvokeScript}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    # echo "PWD: $PWD"
    # echo "out: $out"
    # echo "ls: $(ls)"
    install -m 755 -D --target-directory $out $PWD/${shellInitScript}
    install -m 755 -D --target-directory $out/bin $PWD/${shellInvokeScript}
    runHook postInstall
  '';

} // overridingAttrs)
