# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

DESCRIPTION="Docker complements LXC with a high-level API which operates at the process level. It runs unix processes with strong guarantees of isolation and repeatability across servers."
HOMEPAGE="http://www.docker.io/"
SRC_URI=""

EGIT_REPO_URI="git://github.com/dotcloud/docker.git"
if [[ ${PV} == *9999 ]]; then
	KEYWORDS=""
else
	EGIT_COMMIT="v${PV}"
	KEYWORDS="~amd64"
fi

inherit bash-completion-r1 git-2 linux-info systemd user

LICENSE="Apache-2.0"
SLOT="0"
IUSE=""

DEPEND="
	>=dev-lang/go-1.1
	dev-vcs/git
	dev-vcs/mercurial
"
RDEPEND="
	!app-emulation/lxc-docker-bin
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

pkg_setup() {
	CONFIG_CHECK+=" ~NETFILTER_XT_MATCH_ADDRTYPE ~NF_NAT ~NF_NAT_NEEDED ~AUFS_FS"
	check_extra_config
}

src_compile() {
	if [ -f Makefile ]; then
		emake VERBOSE=1
	else
		# they be stealing our Makefile!
		
		# commands stolen from Dockerfile (go get)
		mkdir -p .gopath/src/github.com/dotcloud || die
		ln -sf "$(pwd -P)" .gopath/src/github.com/dotcloud/docker || die
		# the official revisions of the docker dependencies are in the Dockerfile directly, so we'll just do some lovely sed magic to snag those
		grep $'run\tPKG=' Dockerfile \
			| sed -r 's!^run\t([^;]+);\s*(git|hg).*(git\s+checkout\s+-f|hg\s+checkout).*$!(\1; \2 clone -q http://$PKG .gopath/src/$PKG \&\& cd .gopath/src/$PKG \&\& \3 -q $REV) || die!' \
			| sh || die
		
		# commands stolen from hack/release/make.sh (go build)
		export GOPATH="$(pwd -P)/.gopath"
		VERSION=$(cat ./VERSION)
		GITCOMMIT=$(git rev-parse --short HEAD)
		test -n "$(git status --porcelain)" && GITCOMMIT="$GITCOMMIT-dirty"
		mkdir -p bin || die
		go build -v -o bin/docker -ldflags "-X main.GITCOMMIT $GITCOMMIT -X main.VERSION $VERSION -w" ./docker || die
	fi
}

src_install() {
	dobin bin/docker
	dodoc AUTHORS CONTRIBUTING.md NOTICE README.md
	
	newinitd "${FILESDIR}/docker.initd" docker
	
	systemd_dounit "${FILESDIR}/docker.service"
	
	insinto /usr/share/${P}/contrib
	doins contrib/README contrib/mkimage-*
	cp -R "${S}/contrib"/{docker-build,vagrant-docker} "${D}/usr/share/${P}/contrib/"
	
	if [ -e contrib/docker.bash ]; then
		# install bash completion script if available
		newbashcomp contrib/docker.bash docker
	fi
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
