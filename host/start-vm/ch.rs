// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

use std::ffi::{CStr, OsStr, OsString};
use std::num::NonZeroI32;
use std::os::raw::{c_char, c_int};
use std::os::unix::prelude::*;
use std::process::{Command, Stdio};

use crate::format_mac;

// Trivially safe.
const EPERM: NonZeroI32 = unsafe { NonZeroI32::new_unchecked(1) };
const EPROTO: NonZeroI32 = unsafe { NonZeroI32::new_unchecked(71) };

fn command(vm_name: &OsStr, s: impl AsRef<OsStr>) -> Command {
    let mut api_socket_path = OsString::from("/run/service/ext-");
    api_socket_path.push(vm_name);
    api_socket_path.push("/env/cloud-hypervisor.sock");

    let mut command = Command::new("ch-remote");
    command.stdin(Stdio::null());
    command.arg("--api-socket");
    command.arg(api_socket_path);
    command.arg(s);
    command
}

pub fn add_net(vm_name: &OsStr, tap: RawFd, mac: &str) -> Result<OsString, NonZeroI32> {
    let mut ch_remote = command(vm_name, "add-net")
        .arg(format!("fd={},mac={}", tap, mac))
        .stdout(Stdio::piped())
        .spawn()
        .or(Err(EPERM))?;

    let jq_out = match Command::new("jq")
        .args(&["-j", ".id"])
        .stdin(ch_remote.stdout.take().unwrap())
        .stderr(Stdio::inherit())
        .output()
    {
        Ok(o) => o,
        Err(_) => {
            // Try not to leave a zombie.
            let _ = ch_remote.kill();
            let _ = ch_remote.wait();
            return Err(EPERM);
        }
    };

    if let Ok(ch_remote_status) = ch_remote.wait() {
        if ch_remote_status.success() && jq_out.status.success() {
            return Ok(OsString::from_vec(jq_out.stdout));
        }
    }

    Err(EPROTO)
}

pub fn remove_device(vm_name: &OsStr, device_id: &OsStr) -> Result<(), NonZeroI32> {
    let ch_remote = command(vm_name, "remove-device")
        .arg(device_id)
        .status()
        .or(Err(EPERM))?;

    if ch_remote.success() {
        Ok(())
    } else {
        Err(EPROTO)
    }
}

/// # Safety
///
/// - `vm_name` must point to a valid C string.
/// - `tap` must be a file descriptor describing an tap device.
/// - `mac` must be a valid pointer.
#[export_name = "ch_add_net"]
unsafe extern "C" fn add_net_c(
    vm_name: *const c_char,
    tap: RawFd,
    mac: *const [u8; 6],
    id: *mut *mut OsString,
) -> c_int {
    let vm_name = CStr::from_ptr(vm_name);
    let mac = format_mac(&*mac);

    match add_net(OsStr::from_bytes(vm_name.to_bytes()), tap, &mac) {
        Err(e) => e.get(),
        Ok(id_str) => {
            if !id.is_null() {
                let token = Box::into_raw(Box::new(id_str));
                *id = token;
            }
            0
        }
    }
}

/// # Safety
///
/// - `vm_name` must point to a valid C string.
/// - `id` must be a device ID obtained by calling `add_net_c`.  After
///   calling `remove_device_c`, the pointer is no longer valid.
#[export_name = "ch_remove_device"]
unsafe extern "C" fn remove_device_c(vm_name: *const c_char, device_id: *mut OsString) -> c_int {
    let vm_name = CStr::from_ptr(vm_name);
    let device_id = Box::from_raw(device_id);

    if let Err(e) = remove_device(OsStr::from_bytes(vm_name.to_bytes()), device_id.as_ref()) {
        e.get()
    } else {
        0
    }
}

/// # Safety
///
/// `id` must be a device ID obtained by calling `add_net_c`.  After
/// calling `device_free`, the pointer is no longer valid.
#[export_name = "ch_device_free"]
unsafe extern "C" fn device_free(id: *mut OsString) {
    if !id.is_null() {
        drop(Box::from_raw(id))
    }
}
