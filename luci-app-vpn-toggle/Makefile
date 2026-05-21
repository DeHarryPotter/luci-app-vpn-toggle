include $(TOPDIR)/rules.mk

LUCI_TITLE:=VPN Toggle via PBR
LUCI_DEPENDS:=+pbr +luci-base
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-vpn-toggle
PKG_VERSION:=2.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Nico Groot <nicopen1@live.nl>
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
PKG_SOURCE_URL:=https://github.com/DeHarryPotter/luci-app-vpn-toggle.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=3fde496203a3e5882f277d3a8050c5dc50a991ac

include $(TOPDIR)/feeds/luci/luci.mk

define Package/$(PKG_NAME)/postinst
#!/bin/sh
sed -i 's/\r//' /usr/share/vpn-toggle/user-manager 2>/dev/null
chmod +x /usr/share/vpn-toggle/user-manager 2>/dev/null
exit 0
endef

# call BuildPackage - OpenWrt buildroot signature