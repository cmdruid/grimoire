use skill_grimoire::command::{run_from, SystemConsole};
use skill_grimoire::env::SystemEnvironment;

fn main() {
    let mut console = SystemConsole;
    let code = run_from(std::env::args_os(), &SystemEnvironment, &mut console);
    std::process::exit(i32::from(code));
}
