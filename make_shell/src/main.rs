use std::{path::PathBuf, str::FromStr};

use bpaf::{Bpaf, Parser};
use xshell::{cmd, Shell};

// bpaf docs: https://docs.rs/bpaf/latest/bpaf/index.html
// xshell docs: https://docs.rs/xshell/latest/xshell/index.html

pub struct ShellToml {
    path: PathBuf,
}

#[derive(Debug, Clone)]
enum Phase {
    /// In the build phase:
    ///     * take as input `build.toml`
    ///     * produce as output: `install.toml`
    ///
    /// build.toml has the following format:
    ///```
    ///     shell_dir = "${shellDir}"
    ///     shell_name = "${shellName}"
    ///     shell_hooks = command-list
    ///
    ///     [mkdirs]
    ///     name=path
    ///
    ///     [mkfiles]
    ///     { content = "..."; path = "..."; }
    /// ```
    Build(String),
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
    Install(String),
}

impl FromStr for Phase {
    type Err = anyhow::Error;
    fn from_str(s: &str) -> anyhow::Result<Phase> {
        unimplemented!()
    }
}

/// Template Rust CLI script.
#[derive(Bpaf, Debug, Clone)]
struct MakeShell {
    /// Phase for which to execute actions: one of build or install.
    #[bpaf(positional("PHASE"))]
    phase: Phase,
}

fn main() -> anyhow::Result<()> {
    let opts = make_shell().run();
    unimplemented!();X
    // let sh = Shell::new()?;
    // cmd!(sh, "echo \"{message}\"").run()?;

    Ok(())
}
