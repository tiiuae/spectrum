// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

use std::ffi::{OsStr, OsString};
use std::fs::{create_dir, create_dir_all, File};

use start_vm::vm_command;
use test_helper::TempDir;

fn main() -> std::io::Result<()> {
    let tmp_dir = TempDir::new()?;

    let service_dir = tmp_dir.path().join("testvm");
    create_dir(&service_dir)?;

    let kernel_path = tmp_dir.path().join("svc/data/testvm/vmlinux");
    let image_path = tmp_dir.path().join("svc/data/testvm/blk/root.img");

    create_dir_all(kernel_path.parent().unwrap())?;
    create_dir_all(image_path.parent().unwrap())?;
    File::create(&kernel_path)?;
    File::create(&image_path)?;

    let command = vm_command(service_dir, &tmp_dir.path().join("svc/data")).unwrap();
    assert_eq!(command.get_program(), "s6-notifyoncheck");

    let mut expected_disk_arg = OsString::from("path=");
    expected_disk_arg.push(image_path);
    expected_disk_arg.push(",readonly=on");

    let expected_args = vec![
        OsStr::new("-dc"),
        OsStr::new("test -S env/cloud-hypervisor.sock"),
        OsStr::new("cloud-hypervisor"),
        OsStr::new("--api-socket"),
        OsStr::new("env/cloud-hypervisor.sock"),
        OsStr::new("--cmdline"),
        OsStr::new("console=ttyS0 root=/dev/vda"),
        OsStr::new("--memory"),
        OsStr::new("size=128M"),
        OsStr::new("--console"),
        OsStr::new("pty"),
        OsStr::new("--kernel"),
        kernel_path.as_os_str(),
        OsStr::new("--disk"),
        &expected_disk_arg,
        OsStr::new("--serial"),
        OsStr::new("file=/run/testvm.log"),
    ];

    assert!(command.get_args().eq(expected_args.into_iter()));
    Ok(())
}
