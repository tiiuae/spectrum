// SPDX-License-Identifier: EUPL-1.2
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

use std::ffi::OsStr;
use std::fmt::{self, Display, Formatter};
use std::io;
use std::os::unix::prelude::*;
use std::process::{Command, ExitStatus};

#[derive(Debug)]
pub enum ModprobeError {
    Spawn(io::Error),
    Fail(ExitStatus),
}

impl Display for ModprobeError {
    fn fmt(&self, f: &mut Formatter) -> fmt::Result {
        use ModprobeError::*;
        match self {
            Spawn(e) => write!(f, "failed to spawn modprobe: {}", e),
            Fail(status) => {
                if let Some(code) = status.code() {
                    write!(f, "modprobe exited with status {}", code)
                } else {
                    write!(f, "modprobe killed by signal {}", status.signal().unwrap())
                }
            }
        }
    }
}

pub fn modprobe<I, S>(module_names: I) -> Result<(), ModprobeError>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let status = Command::new("modprobe")
        .arg("-q")
        .arg("--")
        .args(module_names)
        .status()
        .map_err(ModprobeError::Spawn)?;

    if status.success() {
        Ok(())
    } else {
        Err(ModprobeError::Fail(status))
    }
}
