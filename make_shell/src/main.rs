use std::path::PathBuf;

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
    ///     * will take as input shell_def.toml
    ///     * will create shell_invoke.toml which:
    ///         * has the environment variables which need to be invoked
    Build,
    Install,
}

/// Template Rust CLI script.
#[derive(Bpaf, Debug, Clone)]
struct Template {
    /// Phase for which to execute actions: one of build or install.
    #[bpaf(positional("PHASE"))]
    phase: Phase,

    /// Example of a positional argument.
    #[bpaf(positional("POSITIONAL"))]
    shell_toml: String,

    /// Example of an optional argument.
    #[bpaf(argument("OPTIONAL_ARG"), short, long)]
    arg: Option<usize>,

    /// Example of a positional argument.
    #[bpaf(positional("POSITIONAL"))]
    pos: String,
}

fn main() -> anyhow::Result<()> {
    let opts = template().run();
    let greeting = if opts.opt { "goodbye" } else { "hello" };
    let thing = opts.pos.repeat(opts.arg.unwrap_or(1));
    let message = format!("{greeting} {thing}!");
    let sh = Shell::new()?;
    cmd!(sh, "echo \"{message}\"").run()?;

    Ok(())
}
