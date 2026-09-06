use skill_grimoire::command::{run_from, SystemConsole};
use skill_grimoire::env::SystemEnvironment;
use skill_grimoire::runtime::SystemGitRunner;

fn main() {
    let mut console = SystemConsole;
    let git = SystemGitRunner::default();
    let code = run_from(std::env::args_os(), &SystemEnvironment, &mut console, &git);
    std::process::exit(i32::from(code));
}
