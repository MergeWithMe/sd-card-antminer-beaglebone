#!/bin/bash -e

#opensuse support added by: Antonio Cavallo
#https://launchpad.net/~a.cavallo

git_bin=$(which git)

warning () { echo "! $@" >&2; }
error () { echo "* $@" >&2; exit 1; }
info () { echo "+ $@" >&2; }
ltrim () { echo "$1" | awk '{ gsub(/^[ \t]+/,"", $0); print $0}'; }
rtrim () { echo "$1" | awk '{ gsub(/[ \t]+$/,"", $0); print $0}'; }
trim () { local x="$( ltrim "$1")"; x="$( rtrim "$x")"; echo "$x"; }

detect_host () {
	local REV DIST PSEUDONAME

	if [ -f /etc/redhat-release ] ; then
		DIST='RedHat'
		PSEUDONAME=$(cat /etc/redhat-release | sed s/.*\(// | sed s/\)//)
		REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//)
		echo "redhat-$REV"
	elif [ -f /etc/SuSE-release ] ; then
		DIST=$(cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//)
		REV=$(cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //)
		trim "suse-$REV"
	elif [ -f /etc/debian_version ] ; then
		DIST="Debian Based"
		debian="debian"
		echo "${debian}"
	fi
}

check_rpm () {
	pkg_test=$(LC_ALL=C rpm -q "${pkg}")
	if [ "x${pkg_test}" = "xpackage ${pkg} is not installed" ] ; then
		rpm_pkgs="${rpm_pkgs}${pkg} "
	fi
}

redhat_reqs () {
	pkgtool="dnf"

	#https://fedoraproject.org/wiki/Releases
	unset rpm_pkgs
	pkg="redhat-lsb-core"
	check_rpm
	pkg="gcc"
	check_rpm
	pkg="lz4"
	check_rpm
	pkg="ncurses-devel"
	check_rpm
	pkg="wget"
	check_rpm
	pkg="fakeroot"
	check_rpm
	pkg="bison"
	check_rpm
	pkg="flex"
	check_rpm
	pkg="uboot-tools"
	check_rpm
	pkg="openssl-devel"
	check_rpm

	arch=$(uname -m)
	if [ "x${arch}" = "xx86_64" ] ; then
		pkg="ncurses-devel.x86_64"
		check_rpm
		pkg="libmpc-devel.x86_64"
		check_rpm
	fi

	if [ "${rpm_pkgs}" ] ; then
		echo "Red Hat, or derivatives: missing dependencies, please install:"
		echo "-----------------------------"
		echo "${pkgtool} install ${rpm_pkgs}"
		echo "-----------------------------"
		return 1
	fi
}

suse_regs () {
    local BUILD_HOST="$1"   
# --- SuSE-release ---
    if [ ! -f /etc/SuSE-release ]
    then
        cat >&2 <<@@
Missing /etc/SuSE-release file
 this file is part of the efault suse system. If this is a
 suse system for real, please install the package with:
    
    zypper install openSUSE-release   
@@
        return 1
    fi


# --- patch ---
    if [ ! "$( which patch )" ]
    then
        cat >&2 <<@@
Missing patch command,
 it is part of the opensuse $BUILD_HOST distribution so it can be 
 installed simply using:

    zypper install patch

@@
        return 1
    fi
    
}

check_dpkg () {
	LC_ALL=C dpkg-query -s ${pkg} 2>&1 | grep Section: > /dev/null || deb_pkgs="${deb_pkgs}${pkg} "
}

debian_regs () {
	unset deb_pkgs
	pkg="bash"
	check_dpkg
	pkg="bc"
	check_dpkg
	pkg="build-essential"
	check_dpkg
	pkg="fakeroot"
	check_dpkg
	pkg="lsb-release"
	check_dpkg
	pkg="lz4"
	check_dpkg
	pkg="man-db"
	check_dpkg
	#git
	pkg="gettext"
	check_dpkg
	#v4.16-rc0
	pkg="bison"
	check_dpkg
	pkg="flex"
	check_dpkg
	#v4.18-rc0
	pkg="pkg-config"
	check_dpkg
	#GCC_PLUGINS
	pkg="libmpc-dev"
	check_dpkg
	#"mkimage" command not found - U-Boot images will not be built
	pkg="u-boot-tools"
	check_dpkg
	pkg="xz-utils"
	check_dpkg
	pkg="zstd"
	check_dpkg

	unset stop_pkg_search
	#lsb_release might not be installed...
	if [ "$(which lsb_release)" ] ; then
		deb_distro=$(lsb_release -cs | sed 's/\//_/g')

		if [ "x${deb_distro}" = "xn_a" ] ; then
			echo "+ Warning: [lsb_release -cs] just returned [n/a], so now testing [lsb_release -rs] instead..."
			deb_lsb_rs=$(lsb_release -rs | awk '{print $1}' | sed 's/\//_/g')

			#http://docs.kali.org/kali-policy/kali-linux-relationship-with-debian
			#lsb_release -a
			#Distributor ID:    Debian
			#Description:    Debian GNU/Linux Kali Linux 1.0
			#Release:    Kali Linux 1.0
			#Codename:    n/a
			if [ "x${deb_lsb_rs}" = "xKali" ] ; then
				deb_distro="wheezy"
			fi

			#Debian "testing"
			#lsb_release -a
			#Distributor ID: Debian
			#Description:    Debian GNU/Linux testing/unstable
			#Release:        testing/unstable
			#Codename:       n/a
			if [ "x${deb_lsb_rs}" = "xtesting_unstable" ] ; then
				deb_distro="buster"
			fi
		fi

		if [ "x${deb_distro}" = "xtesting" ] ; then
			echo "+ Warning: [lsb_release -cs] just returned [testing], so now testing [lsb_release -ds] instead..."
			deb_lsb_ds=$(lsb_release -ds | awk '{print $1}')

			#http://solydxk.com/about/solydxk/
			#lsb_release -a
			#Distributor ID: SolydXK
			#Description:    SolydXK
			#Release:        1
			#Codename:       testing
			if [ "x${deb_lsb_ds}" = "xSolydXK" ] ; then
				deb_distro="jessie"
			fi
		fi

		if [ "x${deb_distro}" = "xunstable" ] ; then
			echo "+ Warning: [lsb_release -cs] just returned [unstable], so now testing [lsb_release -is] instead..."
			deb_lsb_is=$(lsb_release -is | awk '{print $1}')

			#lsb_release -a
			#Distributor ID: Deepin
			#Description:    Deepin 15.9.2
			#Release:        15.9.2
			#Codename:       unstable
			if [ "x${deb_lsb_is}" = "xDeepin" ] ; then
				deb_distro="stretch"
			fi
		fi

		if [ "x${deb_distro}" = "xluna" ] ; then
			#http://distrowatch.com/table.php?distribution=elementary
			#lsb_release -a
			#Distributor ID:    elementary OS
			#Description:    elementary OS Luna
			#Release:    0.2
			#Codename:    luna
			deb_distro="precise"
		fi

		if [ "x${deb_distro}" = "xfreya" ] ; then
			#http://distrowatch.com/table.php?distribution=elementary
			#lsb_release -a
			#Distributor ID: elementary OS
			#Description:    elementary OS Freya
			#Release:        0.3.1
			#Codename:       freya
			deb_distro="trusty"
		fi

		if [ "x${deb_distro}" = "xtoutatis" ] ; then
			#http://listas.trisquel.info/pipermail/trisquel-announce/2013-March/000014.html
			#lsb_release -a
			#Distributor ID:    Trisquel
			#Description:    Trisquel GNU/Linux 6.0.1, Toutatis
			#Release:    6.0.1
			#Codename:    toutatis
			deb_distro="precise"
		fi

		if [ "x${deb_distro}" = "xbelenos" ] ; then
			#http://listas.trisquel.info/pipermail/trisquel-announce/2014-November/000018.html
			#lsb_release -a
			#Distributor ID:    Trisquel
			#Description:    Trisquel GNU/Linux 7.0, Belenos
			#Release:    7.0
			#Codename:    belenos
			deb_distro="trusty"
		fi

		#https://bugs.kali.org/changelog_page.php
		if [ "x${deb_distro}" = "xmoto" ] ; then
			#lsb_release -a
			#Distributor ID:    Kali
			#Description:    Kali GNU/Linux 1.1.0
			#Release:    1.1.0
			#Codename:    moto
			deb_distro="wheezy"
		fi

		if [ "x${deb_distro}" = "xsana" ] ; then
			#EOL: 15th of April 2016.
			#lsb_release -a
			#Distributor ID:    Kali
			#Description:    Kali GNU/Linux 2.0
			#Release:    2.0
			#Codename:    sana
			deb_distro="jessie"
		fi

		if [ "x${deb_distro}" = "xkali-rolling" ] ; then
			#lsb_release -a:
			#Distributor ID:    Kali
			#Description:    Kali GNU/Linux Rolling
			#Release:    kali-rolling
			#Codename:    kali-rolling
			deb_distro="stretch"
		fi

		#https://www.bunsenlabs.org/
		if [ "x${deb_distro}" = "xbunsen-hydrogen" ] ; then
			#Distributor ID:    BunsenLabs
			#Description:    BunsenLabs GNU/Linux 8.5 (Hydrogen)
			#Release:    8.5
			#Codename:    bunsen-hydrogen
			deb_distro="jessie"
		fi

		#Linux Mint: Compatibility Matrix
		#http://www.linuxmint.com/download_all.php (lists current versions)
		#http://www.linuxmint.com/oldreleases.php
		#http://packages.linuxmint.com/index.php
		#http://mirrors.kernel.org/linuxmint-packages/dists/
		case "${deb_distro}" in
		betsy)
			#LMDE 2
			deb_distro="jessie"
			;;
		cindy)
			#LMDE 3 https://linuxmint.com/rel_cindy.php
			deb_distro="stretch"
			;;
		debbie)
			#LMDE 4
			#http://packages.linuxmint.com/index.php
			deb_distro="buster"
			;;
		elsie)
			#LMDE 5
			#http://packages.linuxmint.com/index.php
			deb_distro="bullseye"
			;;
		faye)
			#LMDE 6
			#http://packages.linuxmint.com/index.php
			deb_distro="bookworm"
			;;
		debian)
			deb_distro="jessie"
			;;
		isadora)
			#9
			deb_distro="lucid"
			;;
		julia)
			#10
			deb_distro="maverick"
			;;
		katya)
			#11
			deb_distro="natty"
			;;
		lisa)
			#12
			deb_distro="oneiric"
			;;
		maya)
			#13
			deb_distro="precise"
			;;
		nadia)
			#14
			deb_distro="quantal"
			;;
		olivia)
			#15
			deb_distro="raring"
			;;
		petra)
			#16
			deb_distro="saucy"
			;;
		qiana)
			#17
			deb_distro="trusty"
			;;
		rebecca)
			#17.1
			deb_distro="trusty"
			;;
		rafaela)
			#17.2
			deb_distro="trusty"
			;;
		rosa)
			#17.3
			deb_distro="trusty"
			;;
		sarah)
			#18
			#http://blog.linuxmint.com/?p=2975
			deb_distro="xenial"
			;;
		serena)
			#18.1
			#http://packages.linuxmint.com/index.php
			deb_distro="xenial"
			;;
		sonya)
			#18.2
			#http://packages.linuxmint.com/index.php
			deb_distro="xenial"
			;;
		sylvia)
			#18.3
			#http://packages.linuxmint.com/index.php
			deb_distro="xenial"
			;;
		tara)
			#19
			#http://blog.linuxmint.com/?p=2975
			deb_distro="bionic"
			;;
		tessa)
			#19.1
			#https://blog.linuxmint.com/?p=3671
			deb_distro="bionic"
			;;
		tina)
			#19.2
			#https://blog.linuxmint.com/?p=3736
			deb_distro="bionic"
			;;
		tricia)
			#19.3
			#http://packages.linuxmint.com/index.php
			deb_distro="bionic"
			;;
		ulyana)
			#20
			#http://packages.linuxmint.com/index.php
			deb_distro="focal"
			;;
		ulyssa)
			#20.1
			#http://packages.linuxmint.com/index.php
			deb_distro="focal"
			;;
		uma)
			#20.2
			#http://packages.linuxmint.com/index.php
			deb_distro="focal"
			;;
		una)
			#20.3
			#http://packages.linuxmint.com/index.php
			deb_distro="focal"
			;;
		vanessa)
			#21
			#http://packages.linuxmint.com/index.php
			deb_distro="jammy"
			;;
		vera)
			#21.1
			#http://packages.linuxmint.com/index.php
			deb_distro="jammy"
			;;
		victoria)
			#21.2
			#http://packages.linuxmint.com/index.php
			deb_distro="jammy"
			;;
		virginia)
			#21.3
			#http://packages.linuxmint.com/index.php
			deb_distro="jammy"
			;;
		wilma)
			#22
			#http://packages.linuxmint.com/index.php
			deb_distro="noble"
			;;
		xia)
			#22.1
			#http://packages.linuxmint.com/index.php
			deb_distro="noble"
			;;
		esac

		#Devuan: Compatibility Matrix
		#https://en.wikipedia.org/wiki/Devuan
		case "${deb_distro}" in
		beowulf)
			deb_distro="buster"
			;;
		chimaera)
			deb_distro="bullseye"
			;;
		daedalus)
			deb_distro="bookworm"
			;;
		excalibur)
			deb_distro="trixie"
			;;
		freia)
			deb_distro="forky"
			;;
		esac

		#Future Debian Code names:
		case "${deb_distro}" in
		forky)
			#14 forky: https://wiki.debian.org/DebianForky
			deb_distro="sid"
			;;
		duke)
			#15 duke: https://wiki.debian.org/DebianDuke
			deb_distro="sid"
			;;
		esac

		#https://wiki.ubuntu.com/Releases
		unset error_unknown_deb_distro
		case "${deb_distro}" in
		buster|bullseye|bookworm|trixie|forky|duke|sid)
			#https://wiki.debian.org/LTS
			#10 buster: 2024-06-30 https://wiki.debian.org/DebianBuster
			#11 bullseye: 2026 https://wiki.debian.org/DebianBullseye
			#12 bookworm: https://wiki.debian.org/DebianBookworm
			#13 trixie: https://wiki.debian.org/DebianTrixie
			#14 forky: https://wiki.debian.org/DebianForky
			#15 duke: https://wiki.debian.org/DebianDuke
			unset warn_eol_distro
			;;
		squeeze|wheezy|jessie|stretch)
			#https://wiki.debian.org/LTS
			#6 squeeze: 2016-02-29 https://wiki.debian.org/DebianSqueeze
			#7 wheezy: 2018-05-31 https://wiki.debian.org/DebianWheezy
			#8 jessie: 2020-06-30 https://wiki.debian.org/DebianJessie
			#9 stretch: 2022-06-30 https://wiki.debian.org/DebianStretch
			warn_eol_distro=1
			stop_pkg_search=1
			;;
		focal|jammy|noble|oracular|plucky)
			#20.04 focal: (EOL: April 2025) lts: focal -> jammy
			#22.04 jammy: (EOL: April 2027) lts: jammy -> noble
			#24.04 noble: (EOL: June 2029) lts: noble -> xyz
			#24.10 oracular: (EOL: July 2025)
			#25.04 plucky: (EOL: April 2025)
			unset warn_eol_distro
			;;
		hardy|lucid|maverick|natty|oneiric|precise|quantal|raring|saucy|trusty|utopic|vivid|wily|xenial|yakkety|zesty|artful|bionic|cosmic|disco|eoan|groovy|hirsute|impish|kinetic|lunar|mantic)
			#8.04 hardy: (EOL: May 2013) lts: hardy -> lucid
			#10.04 lucid: (EOL: April 2015) lts: lucid -> precise
			#10.10 maverick: (EOL: April 10, 2012)
			#11.04 natty: (EOL: October 28, 2012)
			#11.10 oneiric: (EOL: May 9, 2013)
			#12.04 precise: (EOL: April 28 2017) lts: precise -> trusty
			#12.10 quantal: (EOL: May 16, 2014)
			#13.04 raring: (EOL: January 27, 2014)
			#13.10 saucy: (EOL: July 17, 2014)
			#14.04 trusty: (EOL: April 25, 2019) lts: trusty -> xenial
			#14.10 utopic: (EOL: July 23, 2015)
			#15.04 vivid: (EOL: February 4, 2016)
			#15.10 wily: (EOL: July 28, 2016)
			#16.04 xenial: (EOL: April 2021) lts: xenial -> bionic
			#16.10 yakkety: (EOL: July 20, 2017)
			#17.04 zesty: (EOL: January 2018)
			#17.10 artful: (EOL: July 2018)
			#18.04 bionic: (EOL: April 2023) lts: bionic -> focal
			#18.10 cosmic: (EOL: July 18, 2019)
			#19.04 disco: (EOL: January 23, 2020)
			#19.10 eoan: (EOL: July 2020)
			#20.10 groovy: (EOL: July 2021)
			#21.04 hirsute: (EOL: January 2022)
			#21.10 impish: (EOL: July 2022)
			#22.10 kinetic: (EOL: July 2023)
			#23.04 lunar: (EOL: January 2024)
			#23.10 mantic: (EOL: July 2024)
			warn_eol_distro=1
			stop_pkg_search=1
			;;
		*)
			error_unknown_deb_distro=1
			unset warn_eol_distro
			stop_pkg_search=1
			;;
		esac
	fi

	if [ "$(which lsb_release)" ] && [ ! "${stop_pkg_search}" ] ; then
		deb_arch=$(LC_ALL=C dpkg --print-architecture)

		pkg="libncurses-dev:${deb_arch}"
		check_dpkg
		pkg="libssl-dev:${deb_arch}"
		check_dpkg

		if [ "x${build_git}" = "xtrue" ] ; then
			#git
			pkg="libcurl4-gnutls-dev:${deb_arch}"
			check_dpkg
			pkg="libelf-dev:${deb_arch}"
			check_dpkg
			pkg="libexpat1-dev:${deb_arch}"
			check_dpkg
		fi
	fi

	if [ "${warn_eol_distro}" ] ; then
		echo "End Of Life (EOL) deb based distro detected."
		echo "-----------------------------"
	fi

	if [ "${stop_pkg_search}" ] ; then
		echo "Dependency check skipped, you are on your own."
		echo "-----------------------------"
		unset deb_pkgs
	fi

	if [ "${error_unknown_deb_distro}" ] ; then
		echo "Unrecognized deb based system:"
		echo "-----------------------------"
		echo "Please cut, paste and email to: robertcnelson+bugs@gmail.com"
		echo "-----------------------------"
		echo "git: [$(${git_bin} rev-parse HEAD)]"
		echo "git: [$(cat .git/config | grep url | sed 's/\t//g' | sed 's/ //g')]"
		echo "uname -m: [$(uname -m)]"
		echo "lsb_release -a:"
		lsb_release -a
		echo "-----------------------------"
		return 1
	fi

	if [ "${deb_pkgs}" ] ; then
		echo "Debian/Ubuntu/Mint: missing dependencies, please install these packages via:"
		echo "-----------------------------"
		echo "sudo apt-get update"
		echo "sudo apt-get install ${deb_pkgs}"
		echo "-----------------------------"
		return 1
	fi
}

BUILD_HOST=${BUILD_HOST:="$( detect_host )"}
if [ "$(which lsb_release)" ] ; then
	info "Detected build host [$(lsb_release -sd)]"
	info "host: [$(uname -m)]"
	info "git HEAD commit: [$(${git_bin} rev-parse HEAD)]"
else
	info "Detected build host [$BUILD_HOST]"
	info "host: [$(uname -m)]"
	info "git HEAD commit: [$(${git_bin} rev-parse HEAD)]"
fi

DIR=$PWD
. "${DIR}/version.sh"

if [  -f "${DIR}/.yakbuild" ] ; then
	. "${DIR}/recipe.sh"
fi

ARCH=$(uname -m)

git_bin=$(which git)

git_major=$(LC_ALL=C ${git_bin} --version | awk '{print $3}' | cut -d. -f1)
git_minor=$(LC_ALL=C ${git_bin} --version | awk '{print $3}' | cut -d. -f2)
git_sub=$(LC_ALL=C ${git_bin} --version | awk '{print $3}' | cut -d. -f3)

#debian Stable:
#https://packages.debian.org/stretch/git -> 2.11.0
#https://packages.debian.org/buster/git -> 2.20.1
#https://packages.debian.org/bullseye/git -> 2.30.2
#https://packages.ubuntu.com/bionic/git (18.04) -> 2.17.1
#https://packages.ubuntu.com/focal/git (20.04) -> 2.25.1
#https://packages.ubuntu.com/jammy/git (22.04) -> 2.34.1

compare_major="2"
compare_minor="20"
compare_sub="1"

unset build_git

if [ "${git_major}" -lt "${compare_major}" ] ; then
	build_git="true"
elif [ "${git_major}" -eq "${compare_major}" ] ; then
	if [ "${git_minor}" -lt "${compare_minor}" ] ; then
		build_git="true"
	elif [ "${git_minor}" -eq "${compare_minor}" ] ; then
		if [ "${git_sub}" -lt "${compare_sub}" ] ; then
			build_git="true"
		fi
	fi
fi

echo "-----------------------------"
unset NEEDS_COMMAND
check_for_command () {
	if ! which "$1" >/dev/null 2>&1 ; then
		echo "You're missing command $1"
		NEEDS_COMMAND=1
	else
		version=$(LC_ALL=C $1 $2 | head -n 1)
		echo "$1: $version"
	fi
}

unset NEEDS_COMMAND
check_for_command cpio --version
check_for_command lz4 --version
check_for_command xz --version

if [ "${NEEDS_COMMAND}" ] ; then
	echo "Please install missing commands"
	echo "-----------------------------"
	exit 2
fi

case "$BUILD_HOST" in
    redhat*)
	    redhat_reqs || error "Failed dependency check"
        ;;
    debian*)
	    debian_regs || error "Failed dependency check"
        ;;
    suse*)
	    suse_regs "$BUILD_HOST" || error "Failed dependency check"
        ;;
esac

