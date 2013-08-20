# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

DESCRIPTION="Docker complements LXC with a high-level API which operates at the process level. It runs unix processes with strong guarantees of isolation and repeatability across servers."
HOMEPAGE="http://www.docker.io/"
SRC_URI="http://get.docker.io/builds/Linux/x86_64/docker-v${PV}.tgz"
KEYWORDS="-* ~amd64"

inherit linux-info systemd

LICENSE="Apache-2.0"
SLOT="0"
IUSE=""

DEPEND=""
RDEPEND="
	!app-emulation/lxc-docker
	app-arch/libarchive
	app-emulation/lxc
	net-firewall/iptables
	sys-apps/iproute2
	|| (
		sys-fs/aufs3
		sys-kernel/aufs-sources
	)
"

RESTRICT="strip"

ERROR_AUFS_FS="AUFS_FS is required to be set if and only if aufs-sources are used"

S="${WORKDIR}/docker-v${PV}"

pkg_setup() {
	CONFIG_CHECK+=" ~NETFILTER_XT_MATCH_ADDRTYPE ~NF_NAT ~NF_NAT_NEEDED ~AUFS_FS"
	check_extra_config
}

src_install() {
	dobin docker
	
	newinitd "${FILESDIR}/docker.initd" docker
	
	systemd_dounit "${FILESDIR}/docker.service"
}

pkg_postinst() {
	elog ""
	elog "To use docker, the docker daemon must be running as root. To automatically"
	elog "start the docker daemon at boot, add docker to the default runlevel:"
	elog "  rc-update add docker default"
	elog ""
	
	# create docker group if the code checking for it in /etc/group exists
	enewgroup docker
	
	elog "To use docker as a non-root user, add yourself to the docker group."
	elog ""
	
	ewarn ""
	ewarn "If you want your containers to have access to the public internet or even"
	ewarn "the existing private network, IP Forwarding must be enabled:"
	ewarn "  sysctl -w net.ipv4.ip_forward=1"
	ewarn "or more permanently:"
	ewarn "  echo net.ipv4.ip_forward = 1 > /etc/sysctl.d/${PN}.conf"
	ewarn "Please be mindful of the security implications of enabling IP Forwarding."
	ewarn ""
}
