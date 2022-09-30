// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
// SPDX-FileCopyrightText: 2022 Unikie

mod ch;
mod net;

use std::env::{args, current_dir};
use std::ffi::{CString, OsStr, OsString};
use std::io::{self, ErrorKind};
use std::os::unix::prelude::*;
use std::path::PathBuf;
use std::process::{exit, Command};

use net::{format_mac, net_setup, NetConfig};

fn vm_command(dir: PathBuf) -> Result<Command, String> {
    let dir = dir.into_os_string().into_vec();
    let dir = PathBuf::from(OsString::from_vec(dir));

    let vm_name = dir
        .file_name()
        .ok_or_else(|| "directory has no name".to_string())?;

    if vm_name.as_bytes().contains(&b',') {
        return Err(format!("VM name may not contain a comma: {:?}", vm_name));
    }

    let mut command = Command::new("s6-notifyoncheck");
    command.args(&["-dc", "test -S env/cloud-hypervisor.sock"]);
    command.arg("cloud-hypervisor");
    command.args(&["--api-socket", "env/cloud-hypervisor.sock"]);
    command.args(&["--cmdline", "console=ttyS0 root=PARTLABEL=root"]);
    command.args(&["--memory", "size=128M,shared=on"]);
    command.args(&["--console", "pty"]);
    command.args(&["--seccomp", "log"]);

    let mut definition_path = PathBuf::new();
    definition_path.push("/ext/svc/data");
    definition_path.push(vm_name);

    let net_providers_dir = definition_path.join("providers/net");
    match net_providers_dir.read_dir() {
        Ok(entries) => {
            for r in entries {
                let entry = r
                    .map_err(|e| format!("examining directory entry: {}", e))?
                    .file_name();

                // Safe because provider_name is the name of a directory entry, so
                // can't contain a null byte.
                let provider_name = unsafe { CString::from_vec_unchecked(entry.into_vec()) };

                // Safe because we pass a valid pointer and check the result.
                let NetConfig { fd, mac } = unsafe { net_setup(provider_name.as_ptr()) };
                if fd == -1 {
                    let e = io::Error::last_os_error();
                    return Err(format!("setting up networking failed: {}", e));
                }

                command
                    .arg("--net")
                    .arg(format!("fd={},mac={}", fd, format_mac(&mac)));

                // TODO: to support multiple net providers, we'll need
                // a better naming scheme for tap and bridge devices.
                break;
            }
        }
        Err(e) if e.kind() == ErrorKind::NotFound => {}
        Err(e) => return Err(format!("reading directory {:?}: {}", net_providers_dir, e)),
    }

    command.arg("--kernel").arg({
        let mut kernel = OsString::from("/ext/svc/data/");
        kernel.push(&vm_name);
        kernel.push("/vmlinux");
        kernel
    });

    command.arg("--disk");

    let blk_dir = definition_path.join("blk");
    match blk_dir.read_dir() {
        Ok(entries) => {
            for result in entries {
                let entry = result
                    .map_err(|e| format!("examining directory entry: {}", e))?
                    .path();

                if entry.extension() != Some(OsStr::new("img")) {
                    continue;
                }

                if entry.as_os_str().as_bytes().contains(&b',') {
                    return Err(format!("illegal ',' character in path {:?}", entry));
                }

                let mut arg = OsString::from("path=");
                arg.push(entry);
                arg.push(",readonly=on");
                command.arg(arg);
            }
        }
        Err(e) => return Err(format!("reading directory {:?}: {}", blk_dir, e)),
    }

    if definition_path.join("wayland").exists() {
        command.arg("--gpu").arg({
            let mut gpu = OsString::from("socket=../");
            gpu.push(vm_name);
            gpu.push("-gpu/env/crosvm.sock");
            gpu
        });
    }

    if command.get_args().last() == Some(OsStr::new("--disk")) {
        return Err("no block devices specified".to_string());
    }

    command.arg("--serial").arg({
        let mut serial = OsString::from("file=/run/");
        serial.push(&vm_name);
        serial.push(".log");
        serial
    });

    Ok(command)
}

fn run() -> String {
    let dir = match current_dir().map_err(|e| format!("getting current directory: {}", e)) {
        Ok(dir) => dir,
        Err(e) => return e,
    };

    match vm_command(dir) {
        Ok(mut command) => format!("failed to exec: {}", command.exec()),
        Err(e) => e,
    }
}

fn main() {
    let argv0_option = args().next();
    let argv0 = argv0_option
        .as_ref()
        .map(String::as_str)
        .unwrap_or("start-vm");
    eprintln!("{}: {}", argv0, run());
    exit(1);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vm_name_comma() {
        assert!(vm_command("/v,m".into()).unwrap_err().contains("comma"));
    }
}
