#!/bin/sh -e

#yeah, i'm getting lazy..

wfile=$(mktemp /tmp/builder.XXXXXXXXX)
echo "Working on temp $wfile ..."

cat_files () {
	if [ -f ./patches/external/git/BBDTBS ] ; then
		cat ./patches/external/git/BBDTBS >> ${wfile}
	fi

	if [ -f ./patches/external/git/RT ] ; then
		cat ./patches/external/git/RT >> ${wfile}
	fi

	if [ -f ./patches/external/git/AUFS ] ; then
		cat ./patches/external/git/AUFS >> ${wfile}
	fi

	if [ -f ./patches/external/git/WIRELESS_REGDB ] ; then
		cat ./patches/external/git/WIRELESS_REGDB >> ${wfile}
	fi

	if [ -f ./patches/external/git/KSMBD ] ; then
		cat ./patches/external/git/KSMBD >> ${wfile}
	fi

	if [ -f ./patches/external/git/TI_AMX3_CM3 ] ; then
		cat ./patches/external/git/TI_AMX3_CM3 >> ${wfile}
	fi

	if [ -f ./patches/external/git/WPANUSB ] ; then
		cat ./patches/external/git/WPANUSB >> ${wfile}
	fi

	if [ -f ./patches/external/git/BCFSERIAL ] ; then
		cat ./patches/external/git/BCFSERIAL >> ${wfile}
	fi
}

DIR=$PWD
git_bin=$(which git)
repo="https://github.com/RobertCNelson/ti-linux-kernel/compare"

if [ -e ${DIR}/version.sh ]; then
	unset BRANCH
	unset KERNEL_SHA
	. ${DIR}/version.sh

	if [ ! "${BRANCH}" ] ; then
		BRANCH="master"
	fi

	if [ "${SDK}" ] ; then
		echo "Merge TI Branch; TI SDK: ${SDK}" >> ${wfile}
	fi
	echo "Merge TI Branch; ${repo}/${sdk_git_old_release}...${sdk_git_new_release}" > ${wfile}
	if [ "${SDK}" ] ; then
		echo "TI SDK: ${SDK}" >> ${wfile}
	fi
	cat_files

	${git_bin} commit -a -F ${wfile} -s
	echo "log: git push origin ${BRANCH}"
	${git_bin} push origin ${BRANCH}
fi

echo "Deleting $wfile ..."
rm -f "$wfile"
