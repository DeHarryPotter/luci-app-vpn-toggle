include $(TOPDIR)/rules.mk

LUCI_TITLE:=VPN Toggle via PBR
LUCI_DEPENDS:=+pbr +luci-base
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-vpn-toggle
PKG_VERSION:=1.0.11
PKG_RELEASE:=1
PKG_MAINTAINER:=The_Nicolini <nicopen1@live.nl>
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
PKG_SOURCE_URL:=https://github.com/DeHarryPotter/luci-app-vpn-toggle.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=5df01fa1d205bf890ce1dd12a9534517bb757e08

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature