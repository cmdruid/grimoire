use std::path::Path;
use std::process::{Command, Output};

pub fn run(root: &Path, home: &Path, args: &[&str]) -> Output {
    let mut command = Command::new(env!("CARGO_BIN_EXE_grimoire"));
    command
        .current_dir(root)
        .env("HOME", home)
        .env_remove("GRIMOIRE_HOME")
        .args(args);
    command.output().expect("run grimoire")
}

pub fn stdout(output: &Output) -> String {
    String::from_utf8(output.stdout.clone()).expect("UTF-8 stdout")
}

pub fn stderr(output: &Output) -> String {
    String::from_utf8(output.stderr.clone()).expect("UTF-8 stderr")
}
