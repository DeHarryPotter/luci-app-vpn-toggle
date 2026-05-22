# luci-app-vpn-toggle

A LuCI application for OpenWrt that lets you create **per-device or per-subnet VPN routing rules** using [PBR (Policy Based Routing)](https://github.com/stangri/pbr). Each rule is called a *switch* — it routes a specific device or an entire subnet through either the WAN or a VPN interface.

Users log in to LuCI with their own credentials and see a personal **Toggle** page to flip their switches on or off. Only `root` can access the **Settings** page.

---

## Features

- **Settings page** (admin/root only) — manage users, switches, and VPN routing rules via the LuCI web interface
- **Per-subnet device filtering** — the device dropdown is automatically filtered to only show devices on the selected subnet (from DHCP leases + ARP table + static reservations)
- **Automatic PBR policy creation** — adding a switch automatically creates the PBR policy and firewall forwarding rules; deleting a switch cleans them up
- **Automatic static DHCP lease** — when targeting a specific device, a static DHCP reservation is created automatically so the IP stays fixed (removed when the switch is deleted)
- **DNS policy sync** — when toggling a switch, any PBR DNS policy rule with a matching source address is enabled/disabled alongside it
- **Toggle page** at `Services → VPN Toggle → Toggle` — simple card interface showing the current state of each switch with one-click toggle buttons
- **Per-user isolation** — each user only sees and controls their own switches on the Toggle page
- **Admin-only settings** — the Settings page is hidden from non-root users

---

## How It Works

```
LuCI Settings Page  (root only)
  └─ Manage users:
       - Creates a real Unix user (/etc/passwd + /etc/shadow)
       - Password set via luci.setPassword (same mechanism as router admin)
       - rpcd login entry grants access to luci-app-vpn-toggle
  └─ Manage switches per user:
       - Display name
       - Visible to  (specific user, or all)
       - Subnet      (e.g. 192.168.10.0/24)
       - Device      (optional, specific IP — leave blank for entire subnet)
       - WAN interface
       - VPN interface

On Save & Apply:
  ├─ Creates a PBR policy     →  /etc/config/pbr      (rule: vpntog_<secname>)
  ├─ Creates firewall forward →  /etc/config/firewall
  └─ Creates static DHCP host →  /etc/config/dhcp     (if targeting a specific device)

Toggle Page  (Services → VPN Toggle → Toggle)
  └─ Shows switches assigned to the logged-in user
  └─ Each card shows current state (VPN / Direct) and a toggle button
  └─ Toggle writes to UCI pbr, applies config, restarts pbr service
  └─ DNS policy rules with matching src_addr are toggled at the same time
```

---

## Requirements

- OpenWrt 23.05 or newer
- [`pbr`](https://github.com/stangri/pbr) — Policy Based Routing package
- `luci-base`

---

## Installation

### Option A — Install from the GitHub release (recommended)

Download and install directly on your router:

```sh
cd /tmp
wget https://github.com/DeHarryPotter/luci-app-vpn-toggle/releases/latest/download/luci-app-vpn-toggle_2.0.0-1_all.ipk
opkg update
opkg install pbr
opkg install /tmp/luci-app-vpn-toggle_2.0.0-1_all.ipk
```

Then clear the LuCI cache and reload:

```sh
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache*
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

The app appears under **Services → VPN Toggle** in LuCI.

---

## Troubleshooting

- **PBR Rules not applying**: Ensure the `pbr` service is enabled and running (`/etc/init.d/pbr enabled && /etc/init.d/pbr start`).
- **User cannot see Toggle page**: Verify the user has been added in the **Settings** page and has the correct `rpcd` permissions.
- **DNS Leaks**: If using a VPN, ensure your PBR configuration includes DNS hijacking or specific DNS routing rules.

### Option B — Build from source

Requires a working [OpenWrt build environment](https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem).

```sh
cd openwrt/
./scripts/feeds update -a
./scripts/feeds install luci-app-vpn-toggle
make package/luci-app-vpn-toggle/compile V=s
```

---

## Releases

Pre-built `.ipk` files for all versions are available on the [Releases page](https://github.com/DeHarryPotter/luci-app-vpn-toggle/releases).

| Version | Download |
|---------|----------|
| 2.0.0 *(latest)* | [luci-app-vpn-toggle_2.0.0-1_all.ipk](https://github.com/DeHarryPotter/luci-app-vpn-toggle/releases/download/v2.0.0/luci-app-vpn-toggle_2.0.0-1_all.ipk) |
| 1.0.13  | [luci-app-vpn-toggle_1.0.13-1_all.ipk](https://github.com/DeHarryPotter/luci-app-vpn-toggle/releases/download/v1.0.13/luci-app-vpn-toggle_1.0.13-1_all.ipk) |
| 1.0.12  | [luci-app-vpn-toggle_1.0.12-1_all.ipk](https://github.com/DeHarryPotter/luci-app-vpn-toggle/releases/download/v1.0.12/luci-app-vpn-toggle_1.0.12-1_all.ipk) |
| 1.0.11  | [luci-app-vpn-toggle_1.0.11-1_all.ipk](https://github.com/DeHarryPotter/luci-app-vpn-toggle/releases/download/v1.0.11/luci-app-vpn-toggle_1.0.11-1_all.ipk) |
| 1.0.10  | [luci-app-vpn-toggle_1.0.10-1_all.ipk](https://github.com/DeHarryPotter/luci-app-vpn-toggle/releases/download/v1.0.10/luci-app-vpn-toggle_1.0.10-1_all.ipk) |

---

## Configuration

Switch rules are stored in `/etc/config/vpn_toggle`. Users are managed as real Unix accounts and referenced in `/etc/config/rpcd`.

### Switches
```
config switch
    option display_name   'Work VPN'
    option user           'alice'        # optional — leave blank to show to all users
    option target_subnet  '192.168.10.0/24'
    option target_device  '192.168.10.42'  # optional — omit for entire subnet
    option wan_if         'wan'
    option vpn_if         'wg0'
    option pbr_rule       'vpntog_abc123'  # auto-set on save, do not edit manually
    option enabled        '1'
```

### Users

Users are created through the Settings page, which:
1. Adds an entry to `/etc/passwd` and a locked row to `/etc/shadow`
2. Sets the password via the `luci.setPassword` RPC call
3. Creates an rpcd login section in `/etc/config/rpcd` with `$p$<username>` (shadow auth)

There are no plain-text passwords stored in UCI.

---

## Toggle Page

Navigate to **Services → VPN Toggle → Toggle** in LuCI after logging in.

- Each user sees only their own switches (or all switches if none are user-restricted)
- Cards show the current routing state (VPN or Direct) and the active interface
- Clicking the button instantly rewrites the PBR policy, applies UCI, and restarts `pbr`

---

## License

Apache-2.0 — see [LICENSE](LICENSE)

## Maintainer

Nico Groot &lt;nicopen1@live.nl&gt;
