use std::{collections::HashMap, path::PathBuf, str::FromStr};

use anyhow::{anyhow, Context};
use bpaf::{Bpaf, Parser};
use heck::ToSnakeCase;
use toml::{map::Map, Table, Value};
use xshell::{cmd, Shell};

// bpaf docs: https://docs.rs/bpaf/latest/bpaf/index.html
// xshell docs: https://docs.rs/xshell/latest/xshell/index.html

/// Template Rust CLI script.
#[derive(Bpaf, Debug, Clone)]
enum MakeShell {
    /// In the build phase:
    ///     * take as input `build.toml`
    ///     * produce as output: `install.toml`
    ///
    /// build.toml has the following format:
    ///```toml
    /// dir = "${shellDir}"
    /// family = "${shellFamily}"
    /// descr = "${shellDescr}"
    /// hooks = '''${shellHooks}'''
    ///
    /// env_var_dirs = [ { name = "..."; path = "..." }, ]
    /// files = [{ content = '''...'''; path = "..."; }, ]
    /// ```
    #[bpaf(command)]
    Build {
        #[bpaf(positional("BUILD_TOML"))]
        build_toml: String,
    },
    /// In the install phase:
    ///     * take an `install.toml` as a sequence of commands that will be
    ///     executed by something `script_exec`
    ///     * produce as output a series of binaries which will:
    ///         * invoke the shell
    ///             * requires: creating necessary directories if they do not
    ///             exist and initializing necessary environment variables in an
    ///             exec instance of a zsh shell (in the future, a shell of
    ///             choice.)
    ///         * clean up the shell
    ///             * deleting any directories created by shell invocations
    #[bpaf(command)]
    Install {
        #[bpaf(positional("INSTALL_TOML"))]
        install_toml: String,
    },
}

struct EnvDir {
    /// Name of the environment variable that will be associated with this directory.
    name: String,
    path: PathBuf,
}

struct File {
    path: PathBuf,
    content: String,
}

trait PhaseInstructions: FromStr<Err = anyhow::Error> {
    fn execute(self) -> anyhow::Result<()>;
    fn implement(input: &str) -> anyhow::Result<()> {
        Self::from_str(input)?.execute()
    }
}

trait TryFromValue
where
    Self: Sized,
{
    const REQ_TY: &'static str;
    const VALUE_CONVERTER: fn(&Value) -> Option<Self>;

    fn try_from_value(value: &Value) -> anyhow::Result<Self> {
        let err_ctx = || {
            anyhow!("Could not convert value {value:?} into {}", Self::REQ_TY)
        };
        value
            .as_str()
            .ok_or_else(err_ctx)
            .and_then(|s| Self::VALUE_CONVERTER(value).ok_or_else(err_ctx))
    }
}

fn extract_from_table<T: TryFromValue>(
    id: &str,
    table: &Table,
) -> anyhow::Result<T> {
    table
        .get(id)
        .ok_or(anyhow!("No key called {} in table:\n{table:?}", id))
        .and_then(|value| {
            T::try_from_value(value).with_context(|| {
                format!("Could not parse {value:?} as {}", T::REQ_TY)
            })
        })
}

impl TryFromValue for String {
    const REQ_TY: &'static str = "String";

    const VALUE_CONVERTER: fn(&Value) -> Option<Self> =
        |v: &Value| Value::as_str(v).map(|s| s.to_string());
}

impl TryFromValue for PathBuf {
    const REQ_TY: &'static str = "PathBuf";

    const VALUE_CONVERTER: fn(&Value) -> Option<Self> =
        |v: &Value| Value::as_str(v).and_then(|s| PathBuf::from_str(s).ok());
}

impl TryFromValue for Vec<EnvDir> {
    const REQ_TY: &'static str = "Vec<EnvDir>";

    const VALUE_CONVERTER: fn(&Value) -> Option<Self> = |v: &Value| {
        Value::as_array(v)?
            .iter()
            .map(|x| EnvDir::try_from_value(x).ok())
            .collect::<Option<Self>>()
    };
}

impl TryFromValue for EnvDir {
    const REQ_TY: &'static str = "EnvVar";

    const VALUE_CONVERTER: fn(&Value) -> Option<Self> = |v: &Value| {
        let table = Value::as_table(v)?;
        Some(EnvDir {
            name: String::try_from_value(table.get("name")?).ok()?,
            path: PathBuf::try_from_value(table.get("path")?).ok()?,
        })
    };
}

impl TryFromValue for Vec<File> {
    const REQ_TY: &'static str = "Array";

    const VALUE_CONVERTER: fn(&Value) -> Option<Self> = |v: &Value| {
        Value::as_array(v)?
            .iter()
            .map(|x| File::try_from_value(x).ok())
            .collect::<Option<Self>>()
    };
}

impl TryFromValue for File {
    const REQ_TY: &'static str = "Array";

    const VALUE_CONVERTER: fn(&Value) -> Option<Self> = |v: &Value| {
        let table = Value::as_table(v)?;
        Some(File {
            path: PathBuf::try_from_value(table.get("path")?).ok()?,
            content: String::try_from_value(table.get("name")?).ok()?,
        })
    };
}

struct BuildInstructions {
    dir: PathBuf,
    family: String,
    tag: String,
    hooks: String,
    sub_dirs: Vec<EnvDir>,
    files: Vec<File>,
}

impl FromStr for BuildInstructions {
    type Err = anyhow::Error;
    fn from_str(s: &str) -> anyhow::Result<Self> {
        let table = Table::from_str(s)?;
        Ok(Self {
            dir: extract_from_table::<PathBuf>("dir", &table)?,
            family: extract_from_table::<String>("dir", &table)?,
            tag: extract_from_table::<String>("dir", &table)?,
            hooks: extract_from_table::<String>("dir", &table)?,
            sub_dirs: extract_from_table::<Vec<EnvDir>>("dir", &table)?,
            files: extract_from_table::<Vec<File>>("dir", &table)?,
        })
    }
}

impl PhaseInstructions for BuildInstructions {
    fn execute(self) -> anyhow::Result<()> {
        let Self {
            dir,
            family,
            tag,
            hooks,
            sub_dirs,
            files,
        } = self;
        let sh = Shell::new()?;
        unimplemented!()
    }
}

pub struct InstallInstructions {}

impl FromStr for InstallInstructions {
    type Err = anyhow::Error;
    fn from_str(s: &str) -> anyhow::Result<Self> {
        unimplemented!()
    }
}

impl PhaseInstructions for InstallInstructions {
    fn execute(self) -> anyhow::Result<()> {
        todo!()
    }
}

fn build(
    instructions: anyhow::Result<BuildInstructions>,
) -> anyhow::Result<()> {
    unimplemented!()
}

impl TryFrom<anyhow::Result<Map<String, Value>>> for InstallInstructions {
    type Error = anyhow::Error;

    fn try_from(
        value: anyhow::Result<Map<String, Value>>,
    ) -> anyhow::Result<Self> {
        todo!()
    }
}

fn install(
    instructions: anyhow::Result<InstallInstructions>,
) -> anyhow::Result<()> {
    unimplemented!()
}

fn main() -> anyhow::Result<()> {
    let subcmd = make_shell().run();

    match subcmd {
        MakeShell::Build { build_toml } => {
            BuildInstructions::implement(&build_toml)
        }
        MakeShell::Install { install_toml } => {
            InstallInstructions::implement(&install_toml)
        }
    }
}
