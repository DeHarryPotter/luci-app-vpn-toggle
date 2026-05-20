include $(TOPDIR)/rules.mk

LUCI_TITLE:=VPN Toggle via PBR
LUCI_DEPENDS:=+pbr +luci-base
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-vpn-toggle
PKG_VERSION:=1.0.12
PKG_RELEASE:=1
PKG_MAINTAINER:=Nico Groot <nicopen1@live.nl>
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
PKG_SOURCE_URL:=https://github.com/DeHarryPotter/luci-app-vpn-toggle.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=63bad1c5b1719ebcd25d907983e1c0ce5d09ceb2

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature