{ lib, shellInit, ... }:
let
  escapeShellArg = lib.strings.escapeShellArg;

  doubleQuote = x: ''"${x}"'';

  replaceComment = label: action: "# ${action} ${label}";

  bashIfThenElse = { conditionFlag, label, thenExport, elseExport }: ''
    if [ ${conditionFlag} "$''${${label}}" ]
      then
        export ${label}=${thenExport}
      else
        export ${label}=${elseExport}
      fi
  '';
  fixActions = {
    delete = label: {
      find = "export ${label}(.*)$";
      replace = replaceComment label "deleted";
    };
    # when prepending path vars, we choose to prepend to the parent, so that
    # child entries always win over parent entries.
    prepend = label: {
      find = "export ${label}=${doubleQuote "(.+)"}$";
      replace = ''
        ${replaceComment label "prepended"}
        ${bashIfThenElse {
          inherit label;
          conditionFlag = "-z";
          thenExport = doubleQuote "$1";
          elseExport = doubleQuote "$\$${label}:$1";
        }}
      '';
    };
    modify = modifyWith: label: {
      find = "export ${label}=${doubleQuote "(.+)"}$";
      replace = ''
        ${replaceComment label "modified"}
        export ${label}=${doubleQuote modifyWith}'';
    };
    append = label: {
      find = "export ${label}=${doubleQuote "(.+)"}$";
      replace = ''
        ${replaceComment label "appended"}
        ${bashIfThenElse {
          inherit label;
          conditionFlag = "-z";
          thenExport = doubleQuote "$1";
          elseExport = (doubleQuote "$1:$\$${label}");
        }}
      '';
    };
  };

  echoInto = cmd: "echo ${escapeShellArg cmd} ; ${cmd}";

  sdCmd = find: replace:
    echoInto (builtins.concatStringsSep " " [
      "sd"
      (escapeShellArg find)
      (escapeShellArg replace)
      shellInit
    ]);
  fixCmd = fixAction: label:
    let find_replace = fixAction label;
    in with find_replace; echoInto (sdCmd find replace);

  drvAttrs = [
    "__structuredAttrs"
    "buildInputs"
    "buildPhase"
    "builder"
    "cmakeFlags"
    "configureFlags"
    "depsBuildBuild"
    "depsBuildBuildPropagated"
    "depsBuildTarget"
    "depsBuildTargetPropagated"
    "depsHostHost"
    "depsHostHostPropagated"
    "depsTargetTarget"
    "depsTargetTargetPropagated"
    "doCheck"
    "doInstallCheck"
    "installPhase"
    "mesonFlags"
    "meta"
    "nativeBuildInputs"
    "out"
    "outputs"
    "patches"
    "phases"
    "preferLocalBuild"
    "propagatedBuildInputs"
    "propagatedNativeBuildInputs"
    "shell"
    "stdenv"
    "strictDeps"
    "system"
  ];
  builderVars = [
    "GZIP_NO_TIMESTAMPS"
    "NIX_BUILD_TOP"
    "NIX_LOG_FD"
    "OLDPWD"
    "TZ"
    "PWD"
    "SOURCE_DATE_EPOCH"
    "NIX_SSL_CERT_FILE"
    "SSL_CERT_FILE"
    "SHELL"
    "CONFIG_SHELL"
    # "HOST_PATH"
    "HOME"
  ];
  pathLikes = [ "XDG_DATA_DIRS" "PATH" ];
  tempDirs = [ "TEMP" "TMP" "TEMPDIR" "TMPDIR" ];
  SHLVL = "SHLVL";
in builtins.concatStringsSep "\n" ([ (sdCmd "declare -x" "export") ]
  ++ (map (fixCmd fixActions.delete) (drvAttrs ++ builderVars))
  ++ (map (fixCmd fixActions.prepend) pathLikes)
  ++ (map (fixCmd fixActions.append) [ "name" ])
  ++ (map (fixCmd (fixActions.modify "/run/user/$$UID")) tempDirs)
  ++ [ (fixCmd (fixActions.modify "$$((SHLVL - 1))") SHLVL) ])
#++ (map (fixCmd replaceRegex.delete) (drvAttrs ++ builderVars))
#++ (map (fixCmd replaceRegex.prepend) pathLikes)
