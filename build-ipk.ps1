# build-ipk.ps1
# Builds luci-app-vpn-toggle_<version>_all.ipk
# Pure PowerShell + inline C# - no external tools required.

$PKG_NAME    = "luci-app-vpn-toggle"
$PKG_VERSION = "2.1.0"
$PKG_RELEASE = "1"
$PKG_ARCH    = "all"
$OUTPUT      = "$PSScriptRoot\${PKG_NAME}_${PKG_VERSION}-${PKG_RELEASE}_${PKG_ARCH}.ipk"
$ROOT        = "$PSScriptRoot\luci-app-vpn-toggle"
$TMPDIR      = "$env:TEMP\ipk-$(Get-Random)"

# ── inline C# tar.gz builder with proper Unix mode bits ───────────────────────
if (-not ([System.Management.Automation.PSTypeName]'TarGzBuilder').Type) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Text;

public sealed class TarGzBuilder : IDisposable {
    private readonly FileStream _fs;
    private readonly GZipStream _gz;
    private bool _disposed;

    public TarGzBuilder(string outputPath) {
        _fs = new FileStream(outputPath, FileMode.Create, FileAccess.Write);
        _gz = new GZipStream(_fs, CompressionLevel.Optimal);
    }

    private static byte[] OctalField(long value, int width) {
        string s = Convert.ToString(value, 8).PadLeft(width - 1, '0') + "\0";
        return Encoding.ASCII.GetBytes(s.Length > width ? s.Substring(s.Length - width) : s);
    }

    private byte[] MakeHeader(string path, int mode, long size, byte typeFlag) {
        byte[] hdr  = new byte[512];
        byte[] nb   = Encoding.ASCII.GetBytes(path.Length > 99 ? path.Substring(path.Length - 99) : path);
        Buffer.BlockCopy(nb, 0, hdr, 0, nb.Length);
        byte[] modeB = OctalField(mode, 8);  Buffer.BlockCopy(modeB, 0, hdr, 100, modeB.Length);
        byte[] zeroB = OctalField(0,    8);  Buffer.BlockCopy(zeroB, 0, hdr, 108, zeroB.Length);
                                             Buffer.BlockCopy(zeroB, 0, hdr, 116, zeroB.Length);
        byte[] sizeB = OctalField(size, 12); Buffer.BlockCopy(sizeB, 0, hdr, 124, sizeB.Length);
        long mt = (long)(DateTime.UtcNow - new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc)).TotalSeconds;
        byte[] mtB   = OctalField(mt,   12); Buffer.BlockCopy(mtB,   0, hdr, 136, mtB.Length);
        hdr[156] = typeFlag;
        // checksum: fill with spaces, sum all bytes, write octal
        for (int i = 148; i < 156; i++) hdr[i] = 0x20;
        int ck = 0; for (int i = 0; i < 512; i++) ck += hdr[i];
        byte[] ckB = Encoding.ASCII.GetBytes(Convert.ToString(ck, 8).PadLeft(6, '0'));
        Buffer.BlockCopy(ckB, 0, hdr, 148, ckB.Length);
        hdr[154] = 0; hdr[155] = 0x20;
        return hdr;
    }

    public void AddFile(string arcPath, string filePath, int mode) {
        arcPath = "./" + arcPath.TrimStart('.', '/').Replace('\\', '/');
        byte[] data = File.ReadAllBytes(filePath);
        _gz.Write(MakeHeader(arcPath, mode, data.Length, (byte)'0'), 0, 512);
        _gz.Write(data, 0, data.Length);
        int pad = (512 - (data.Length % 512)) % 512;
        if (pad > 0) _gz.Write(new byte[pad], 0, pad);
    }

    public void AddDirectory(string arcPath, int mode) {
        arcPath = "./" + arcPath.TrimStart('.', '/').Replace('\\', '/');
        if (!arcPath.EndsWith("/")) arcPath += "/";
        _gz.Write(MakeHeader(arcPath, mode, 0, (byte)'5'), 0, 512);
    }

    public void Dispose() {
        if (_disposed) return;
        _disposed = true;
        _gz.Write(new byte[1024], 0, 1024); // end-of-archive marker
        _gz.Dispose();
        _fs.Dispose();
    }
}
'@
}

function New-Dir($p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }

# Write a text file with Unix (LF) line endings
function Write-Unix($path, $text) {
    $lf    = $text -replace "`r`n", "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($lf)
    [System.IO.File]::WriteAllBytes($path, $bytes)
}

$EXEC_NAMES = @('user-manager', 'luci-app-vpn-toggle', 'postinst', 'preinst', 'postrm', 'prerm')

function Build-ControlTarGz($srcDir, $outPath) {
    $tar = New-Object TarGzBuilder($outPath)
    try {
        Get-ChildItem -File $srcDir | ForEach-Object {
            $tar.AddFile($_.Name, $_.FullName, 493)  # 0755 octal
        }
    } finally { $tar.Dispose() }
}

function Build-DataTarGz($srcDir, $outPath) {
    $tar = New-Object TarGzBuilder($outPath)
    try {
        Get-ChildItem -Recurse -Directory $srcDir | ForEach-Object {
            $rel = $_.FullName.Substring($srcDir.Length + 1)
            $tar.AddDirectory($rel, 493)  # 0755 octal
        }
        Get-ChildItem -Recurse -File $srcDir | ForEach-Object {
            $rel  = $_.FullName.Substring($srcDir.Length + 1)
            $mode = if ($EXEC_NAMES -contains $_.Name) { 493 } else { 420 }  # 0755 / 0644 octal
            $tar.AddFile($rel, $_.FullName, $mode)
        }
    } finally { $tar.Dispose() }
}

function Build-IpkTarGz($pkgDir, $outPath) {
    $tar = New-Object TarGzBuilder($outPath)
    try {
        @('debian-binary', 'control.tar.gz', 'data.tar.gz') | ForEach-Object {
            $tar.AddFile($_, "$pkgDir\$_", 0644)
        }
    } finally { $tar.Dispose() }
}

# ── staging ───────────────────────────────────────────────────────────────────
New-Dir "$TMPDIR\pkg"
New-Dir "$TMPDIR\ctrl"
New-Dir "$TMPDIR\data\www\luci-static\resources\view\vpn_toggle"
New-Dir "$TMPDIR\data\etc\config"
New-Dir "$TMPDIR\data\etc\uci-defaults"
New-Dir "$TMPDIR\data\usr\share\luci\menu.d"
New-Dir "$TMPDIR\data\usr\share\rpcd\acl.d"
New-Dir "$TMPDIR\data\usr\share\vpn-toggle"

# ── copy source files ─────────────────────────────────────────────────────────
Copy-Item -Recurse "$ROOT\htdocs\luci-static\*"                                   "$TMPDIR\data\www\luci-static\"       -Force
Copy-Item          "$ROOT\root\etc\config\vpn_toggle"                             "$TMPDIR\data\etc\config\"            -Force
Copy-Item          "$ROOT\root\usr\share\luci\menu.d\luci-app-vpn-toggle.json"    "$TMPDIR\data\usr\share\luci\menu.d\" -Force
Copy-Item          "$ROOT\root\usr\share\rpcd\acl.d\luci-app-vpn-toggle.json"         "$TMPDIR\data\usr\share\rpcd\acl.d\"  -Force
Copy-Item          "$ROOT\root\usr\share\rpcd\acl.d\luci-app-vpn-toggle-admin.json"   "$TMPDIR\data\usr\share\rpcd\acl.d\"  -Force
Copy-Item          "$ROOT\root\usr\share\vpn-toggle\user-manager"                      "$TMPDIR\data\usr\share\vpn-toggle\" -Force
Copy-Item          "$ROOT\root\etc\uci-defaults\luci-app-vpn-toggle"                   "$TMPDIR\data\etc\uci-defaults\"      -Force

# ── control files ─────────────────────────────────────────────────────────────
Write-Unix "$TMPDIR\ctrl\control" @"
Package: $PKG_NAME
Version: ${PKG_VERSION}-${PKG_RELEASE}
Architecture: $PKG_ARCH
Maintainer: local
Depends: pbr, luci-base
Description: VPN Toggle via PBR
 LuCI settings page and standalone toggle UI for per-device VPN routing
 using PBR (Policy-Based Routing) policies.

"@

Write-Unix "$TMPDIR\ctrl\conffiles" "/etc/config/vpn_toggle`n"

Write-Unix "$TMPDIR\ctrl\postinst" "#!/bin/sh`nrm -f /tmp/luci-indexcache* && rm -rf /tmp/luci-modulecache*`n/etc/init.d/rpcd restart`n/etc/init.d/uhttpd restart`nexit 0`n"

# ── build archives ────────────────────────────────────────────────────────────
Build-ControlTarGz "$TMPDIR\ctrl" "$TMPDIR\pkg\control.tar.gz"
Build-DataTarGz    "$TMPDIR\data" "$TMPDIR\pkg\data.tar.gz"
Write-Unix         "$TMPDIR\pkg\debian-binary" "2.0`n"
Build-IpkTarGz     "$TMPDIR\pkg" $OUTPUT

# ── cleanup ───────────────────────────────────────────────────────────────────
Remove-Item -Recurse -Force $TMPDIR

Write-Host ""
Write-Host "Built: $OUTPUT"
Write-Host ""
Write-Host "Deployment examples for 192.168.44.1"
Write-Host "------------------------------------------------------"
Write-Host "Option 1: Using standard SSH/SCP"
Write-Host "  scp -O `"$OUTPUT`" root@192.168.44.1:/tmp/"
Write-Host "  ssh root@192.168.44.1 'opkg update && opkg install pbr && opkg install /tmp/$($PKG_NAME)_$($PKG_VERSION)-1_all.ipk'"
Write-Host ""
Write-Host "Option 2: Using Plink/PSCP"
Write-Host "  pscp `"$OUTPUT`" root@192.168.44.1:/tmp/"
Write-Host "  plink -ssh root@192.168.44.1 \"opkg update && opkg install pbr && opkg install /tmp/$($PKG_NAME)_$($PKG_VERSION)-1_all.ipk\""
