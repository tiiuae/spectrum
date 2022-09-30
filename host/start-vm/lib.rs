// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

mod ch;
mod net;

use std::borrow::Cow;
use std::env::args_os;
use std::ffi::{CString, OsStr, OsString};
use std::io::{self, ErrorKind};
use std::os::unix::prelude::*;
use std::path::{Path, PathBuf};
use std::process::Command;

use net::{format_mac, net_setup, NetConfig};

pub fn prog_name() -> String {
    args_os()
        .next()
        .as_ref()
        .map(Path::new)
        .and_then(Path::file_name)
        .map(OsStr::to_string_lossy)
        .unwrap_or(Cow::Borrowed("start-vm"))
        .into_owned()
}

pub fn vm_command(dir: PathBuf, config_root: &Path) -> Result<Command, String> {
    let dir = dir.into_os_string().into_vec();
    let dir = PathBuf::from(OsString::from_vec(dir));

    let vm_name = dir
        .file_name()
        .ok_or_else(|| "directory has no name".to_string())?;

    if vm_name.as_bytes().contains(&b',') {
        return Err(format!("VM name may not contain a comma: {:?}", vm_name));
    }

    let config_dir = config_root.join(vm_name);

    let mut command = Command::new("s6-notifyoncheck");
    command.args(&["-dc", "test -S env/cloud-hypervisor.sock"]);
    command.arg("cloud-hypervisor");
    command.args(&["--api-socket", "env/cloud-hypervisor.sock"]);
    command.args(&["--cmdline", "console=ttyS0 root=PARTLABEL=root"]);
    command.args(&["--memory", "size=128M,shared=on"]);
    command.args(&["--console", "pty"]);
    command.arg("--kernel");
    command.arg(config_dir.join("vmlinux"));

    let net_providers_dir = config_dir.join("providers/net");
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

    command.arg("--disk");

    let blk_dir = config_dir.join("blk");
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vm_name_comma() {
        assert!(vm_command("/v,m".into(), Path::new("/"))
            .unwrap_err()
            .contains("comma"));
    }
}
