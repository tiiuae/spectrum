// SPDX-License-Identifier: EUPL-1.2
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

use std::os::raw::c_char;

#[repr(C)]
pub struct NetConfig {
    pub fd: i32,
    pub mac: [u8; 6],
}

extern "C" {
    pub fn net_setup(provider_vm_name: *const c_char) -> NetConfig;
}

pub fn format_mac(mac: &[u8; 6]) -> String {
    format!(
        "{:02X}:{:02X}:{:02X}:{:02X}:{:02X}:{:02X}",
        mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_mac_all_zero() {
        assert_eq!(format_mac(&[0; 6]), "00:00:00:00:00:00");
    }

    #[test]
    fn format_mac_hex() {
        let mac = [0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54];
        assert_eq!(format_mac(&mac), "FE:DC:BA:98:76:54");
    }
}
