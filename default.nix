# mkDevShell is closely based on the structure of mkShell
# * https://stackoverflow.com/a/71112117/3486684
# ===========================================
# mkShell Attributes:
# https://nixos.org/manual/nixpkgs/unstable/#sec-pkgs-mkShell-attributes
# ===========================================
# https://github.com/NixOS/nixpkgs/blob/nixos-23.05/pkgs/build-support/mkshell/default.nix
{ pkgs, lib, stdenv, buildEnv, ... }:
{ pkgs, lib,
# shell names have the form: "family_description"
shellName,
# where the shell's directories will live is determined in part by this value:
# `$baseDir/${shellName.family}/${shellName.description}`
baseDir,
# dirs that will be made, and added as env vars
# structure: { DIR_NAME = String; }
mkdirs ? { },
# files that will be made, and copied to requested path at script start
# structure: [{ text = String; path = String; }]
mkfiles ? [ ],
# packages that will be made available in the shell env
packages ? [ ],
# packages whose build inputs will be made available in the shell env
useInputsFrom ? [ ], meta ? { }, ... }@inputAttrs:
let
  # de-duplicates values of `inp` found in `useInputsFrom`
  mergeBuildInputs = inp:
    # check if there is an attribute with the same name as `inp` in this
    # `mkDevShell's` input attributes; if so, get it, otherwise begin with the
    # empty list
    (inputAttrs.${inp} or [ ]) ++
    # lib.subtractLists: subtracts first list from second
    # https://nixos.org/manual/nixpkgs/unstable/
    lib.subtractLists useInputsFrom (
      # flattens nested lists into an un-nested one
      lib.flatten
      # collect each attribute named attr from a list of attrsets
      (lib.catAttrs inp useInputsFrom));

  unmodifiedAttrs = builtins.removeAttrs inputAttrs
    # These are the attributes that we will override/merge from `inputAttrs`.
    [
      "name"
      "packages"
      "useInputsFrom"
      "buildInputs"
      "nativeBuildInputs"
      "propagatedBuildInputs"
      "propagatedNativeBuildInputs"
      "shellHook"
    ];

  # Minimal stdenv based on: https://github.com/viperML/mkshell-minimal
  miniStdEnv = stdenv.override {
    extraNativeBuildInputs = [ pkgs.sd ];
    cc = null;
    preHook = "";
    allowedRequisites = null;
    initialPath = [ pkgs.coreutils ];
    shell = pkgs.lib.getExe pkgs.bash;
  };
  IN_NIX_SHELL = "impure"; # these custom shells are impure by construction
  name = "${shellName.family}_${shellName.description}";
  shellDir = "${baseDir}/${shellName.family}/${shellName.description}";
  phases = map (x: "${x}Phase") [ "build" "install" ];
in miniStdEnv.mkDerivation ({
  inherit name meta phases IN_NIX_SHELL;

  buildInputs = mergeBuildInputs "buildInputs";
  nativeBuildInputs = packages ++ (mergeBuildInputs "nativeBuildInputs");
  propagatedBuildInputs = mergeBuildInputs "propagatedBuildInputs";
  propagatedNativeBuildInputs = mergeBuildInputs "propagatedNativeBuildInputs";
  preferLocalBuild = true;

  buildPhase = let
    tomlMultiLineLiteral = let singleQuoteTriple = "'''";
    in x: "${singleQuoteTriple}${x}${singleQuoteTriple}";
    # a concatenation of the various shell hooks that are required by the
    # buildInputs that go into making up the shell environment
    buildToml = ''
      shell_dir = "${shellDir}"
      shell_name = "${shellName}"
      shell_hooks = ${
        tomlMultiLineLiteral (lib.concatStringsSep "\n"
          (lib.catAttrs "shellHook"
            (lib.reverseList useInputsFrom ++ [ inputAttrs ])))
      }

      [mkdirs]
      ${let toStringNameValue = { name, value }: "${name}=${value}";
      in builtins.concatStringsSep "\n"
      (map toStringNameValue (lib.attrsToList mkdirs))}

      [mkfiles]
      ${let
        attrSetToString = { contents, path }: ''
          {
            contents = ${contents};
            path = "${path}";
          }
        '';
      in builtins.concatStringsSep "\n" (map attrSetToString mkfiles)}
    '';
  in ''
    runHook preBuild
    make_shell build ${buildToml}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make_shell install --out $out --shell_def $PWD/shell_def.toml
    runHook postInstall
  '';

} // unmodifiedAttrs)
