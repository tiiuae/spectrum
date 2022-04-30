// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

use std::ffi::OsString;
use std::io;
use std::mem::{forget, swap};
use std::os::raw::c_char;
use std::os::unix::prelude::*;
use std::path::{Path, PathBuf};

use start_vm::prog_name;

extern "C" {
    fn mkdtemp(template: *mut c_char) -> *mut c_char;
}

// FIXME: once OnceCell is in the standard library, we won't need a
// function for this any more.
// https://github.com/rust-lang/rust/issues/74465
fn tmpdir() -> std::path::PathBuf {
    std::env::var_os("TMPDIR")
        .unwrap_or_else(|| OsString::from("/tmp"))
        .into()
}

pub struct TempDir(PathBuf);

impl TempDir {
    pub fn new() -> std::io::Result<Self> {
        let mut dirname = OsString::from("spectrum-start-vm-test-");
        dirname.push(prog_name());
        dirname.push(".XXXXXX");
        let mut template = tmpdir();
        template.push(dirname);

        let c_path = Box::into_raw(template.into_os_string().into_vec().into_boxed_slice());

        // Safe because we own c_path.
        if unsafe { mkdtemp(c_path as *mut c_char) }.is_null() {
            return Err(io::Error::last_os_error());
        }

        // Safe because we own c_path and it came from Box::into_raw.
        let path = PathBuf::from(OsString::from_vec(unsafe { Box::from_raw(c_path) }.into()));
        Ok(Self(path))
    }

    pub fn path(&self) -> &Path {
        self.0.as_path()
    }

    /// The `TempDir` Drop handler will not be run, so the caller takes responsibility
    /// for removing the directory when no longer required.
    pub fn into_path_buf(mut self) -> PathBuf {
        let mut path = PathBuf::new();
        swap(&mut path, &mut self.0);
        forget(self);
        path
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}
