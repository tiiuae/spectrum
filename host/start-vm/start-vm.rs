// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
// SPDX-FileCopyrightText: 2022 Unikie

use std::env::current_dir;
use std::os::unix::prelude::*;
use std::path::Path;
use std::process::exit;

use start_vm::{prog_name, vm_command};

const CONFIG_ROOT: &str = "/ext/svc/data";

fn run() -> String {
    let dir = match current_dir().map_err(|e| format!("getting current directory: {}", e)) {
        Ok(dir) => dir,
        Err(e) => return e,
    };

    match vm_command(dir, Path::new(CONFIG_ROOT)) {
        Ok(mut command) => format!("failed to exec: {}", command.exec()),
        Err(e) => e,
    }
}

fn main() {
    eprintln!("{}: {}", prog_name(), run());
    exit(1);
}
