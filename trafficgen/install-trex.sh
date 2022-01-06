#!/bin/bash

full_script_path=$(readlink -e ${0})
tgen_dir=$(dirname ${full_script_path})

base_dir="/opt/trex"
repo_name="trex-core"
tmp_dir="/tmp"
trex_ver="v2.93"
force_install=0
toolbox_url=https://github.com/perftool-incubator/toolbox.git

opts=$(getopt -q -o c: --longoptions "tmp-dir:,base-dir:,version:,force" -n "getopt.sh" -- "$@")
if [ $? -ne 0 ]; then
    printf -- "$*\n"
    printf -- "\n"
    printf -- "\tThe following options are available:\n\n"
    printf -- "\n"
    printf -- "--tmp-dir=str\n"
    printf -- "  Directory where temporary files should be stored.\n"
    printf -- "  Default is ${tmp_dir}\n"
    printf -- "\n"
    printf -- "--base-dir=str\n"
    printf -- "  Directory where TRex will be installed.\n"
    printf -- "  Default is ${base_dir}\n"
    printf -- "\n"
    printf -- "--version=str\n"
    printf -- "  Version of TRex to install\n"
    printf -- "  Default is ${trex_ver}\n"
    printf -- "\n"
    printf -- "--force\n"
    printf -- "  Download and install TRex even if it is already present.\n"
    exit 1
fi
eval set -- "$opts"
while true; do
    case "${1}" in
	--tmp-dir)
	    shift
	    if [ -n "${1}" ]; then
		tmp_dir=${1}
		shift
	    fi
	    ;;
	--base-dir)
	    shift
	    if [ -n "${1}" ]; then
		base_dir=${1}
		shift
	    fi
	    ;;
	--version)
	    shift
	    if [ -n "${1}" ]; then
		trex_ver=${1}
		shift
	    fi
	    ;;
	--force)
	    shift
	    force_install=1
	    ;;
	--)
	    break
	    ;;
	*)
	    if [ -n "${1}" ]; then
		echo "ERROR: Unrecognized option ${1}"
	    fi
	    exit 1
	    ;;
    esac
done

trex_dir="${base_dir}/trex-core"

if [ -d ${trex_dir} -a "${force_install}" == "0" ]; then
    echo "TRex ${trex_ver} already installed"
else
    if [ -d ${trex_dir} ]; then
	/bin/rm -Rf ${trex_dir}
    fi

    mkdir -p ${base_dir}
    if pushd ${base_dir} >/dev/null; then
	echo "Git cloning trex-core:"
	git clone https://github.com/cisco-system-traffic-generator/trex-core.git
	if pushd trex-core > /dev/null; then
	    echo "Git remotes:"
	    git remote -v

	    echo "Git status:"
	    git status

	    echo "Git tags:"
	    git tag -l

	    echo "Checking out git tag (${trex_ver}):"
	    git checkout ${trex_ver}

	    echo "Git status:"
	    git status

	    # enabled IEEE 1588
	    echo "Enabling IEEE1588 latency testing:"
	    grep IEEE1588 src/pal/linux_dpdk/dpdk_2102_x86_64/rte_config.h
	    sed -i -e "s|^//\(#define.*IEEE1588.*\)|\1|" src/pal/linux_dpdk/dpdk_2102_x86_64/rte_config.h
	    grep IEEE1588 src/pal/linux_dpdk/dpdk_2102_x86_64/rte_config.h

	    # build it
	    if pushd linux_dpdk; then
		echo "Configure:"
		if ! ./b configure --no-mlx=NO_MLX; then
		    echo "ERROR: Failed to configure TRex build"
		    exit 1
		fi

		echo "Build:"
		if ! ./b build; then
		    echo "ERROR: Failed to build TRex"
		    exit 1
		fi
	    else
		echo "ERROR: Failed to pushd to linux_dpdk!"
		exit 1
	    fi

	    popd > /dev/null
	else
	    echo "ERROR: Failed to git clone trex-core"
	    exit 1
	fi
    else
	echo "ERROR: Could not use ${base_dir}"
	exit 1
    fi
fi

# we need a symlink so our trex scripts can always point to
# same location for trex
if pushd ${base_dir} >/dev/null; then
    /bin/rm -f current 2>/dev/null
    ln -sf trex-core/scripts current
    popd >/dev/null
fi

if [ ! -d ${tgen_dir}/toolbox ]; then
    if pushd ${tgen_dir} > /dev/null; then
        echo "Installing toolbox..."
        git clone ${toolbox_url}

        popd > /dev/null
    fi
else
    if pushd ${tgen_dir}/toolbox > /dev/null; then
        echo "Updating toolbox..."
        git fetch --all
        git pull --ff-only

        popd > /dev/null
    fi
fi
