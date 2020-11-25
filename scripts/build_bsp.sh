#!/bin/bash
# Copyright (c) 2018 Nexell Co., Ltd.
# Author: Junghyun, Kim <jhkim@nexell.co.kr>
#

eval "$(locale | sed -e 's/\(.*\)=.*/export \1=en_US.UTF-8/')"

EDIT_TOOL="vim"	# editor with '-e' option

# config script's environment elements
declare -A BUILD_CONFIG_ENV=(
	["CROSS_TOOL"]=" "
	["RESULT_DIR"]=" "
)

# config script's target elements
declare -A BUILD_CONFIG_TARGET=(
	["BUILD_MANUAL"]=" "	# manual build, It true, does not support automatic build and must be built manually.
	["CROSS_TOOL"]=" "	# make build crosstool compiler path (set CROSS_COMPILE=)
	["MAKE_ARCH"]=" "	# make build architecture (set ARCH=) ex> arm, arm64
	["MAKE_PATH"]=" "	# make build source path
	["MAKE_CONFIG"]=""	# make build default config(defconfig)
	["MAKE_TARGET"]=""	# make build targets, to support multiple targets, the separator is';'
	["MAKE_NOT_CLEAN"]=""	# if true do not support make clean commands
	["MAKE_OPTION"]=""	# make build option
	["RESULT_FILE"]=""	# make built images to copy resultdir, to support multiple targets, the separator is';'
	["RESULT_NAME"]=""	# copy names to RESULT_DIR, to support multiple targets, the separator is';'
	["MAKE_JOBS"]=" "	# make build jobs number (-j n)
	["SCRIPT_PREV"]=" "	# previous build script before make build.
	["SCRIPT_POST"]=""	# post build script after make build before copy 'RESULT_FILE' done.
	["SCRIPT_LATE"]=""	# late build script after copy 'RESULT_FILE' done.
	["SCRIPT_CLEAN"]=" "	# clean script for clean command.
)

declare -A BUILD_STAGE=(
	["prev"]=true		# execute script 'SCRIPT_PREV'
	["make"]=true		# make with 'MAKE_PATH' and 'MAKE_TARGET'
	["copy"]=true		# execute copy with 'RESULT_FILE and RESULT_NAME'
	["post"]=true		# execute script 'SCRIPT_POST'
	["late"]=true		# execute script 'SCRIPT_LATE'
)

BUILD_BSP_PATH="$(dirname "$(realpath "$0")")"
BUILD_CONFIG_STATUS="$BUILD_BSP_PATH/.build_config"
BUILD_CONFIG_SCRIPT_DIR="$BUILD_BSP_PATH/configs"
BUILD_CONFIG_PREFIX="build."
BUILD_LOG_DIR="log"	# save to result directory

function print_format() {
	echo -e " config.sh: format"
	echo -e "\t BUILD_IMAGES=("
	echo -e "\t\t\" CROSS_TOOL	= <cross compiler(CROSS_COMPILE) path for the make build> \","
	echo -e "\t\t\" RESULT_DIR	= <result directory to copy build images> \","
	echo -e "\t\t\" <TARGET>	="
	echo -e "\t\t\t BUILD_MANUAL    : < manual build, It true, does not support automatic build and must be built manually. > ,"
	echo -e "\t\t\t CROSS_TOOL      : < make build crosstool compiler path (set CROSS_COMPILE=) > ,"
	echo -e "\t\t\t MAKE_ARCH       : < make build architecture (set ARCH=) ex> arm, arm64 > ,"
	echo -e "\t\t\t MAKE_PATH       : < make build source path > ,"
	echo -e "\t\t\t MAKE_CONFIG     : < make build default config(defconfig) > ,"
	echo -e "\t\t\t MAKE_TARGET     : < make build targets, to support multiple targets, the separator is';' > ,"
	echo -e "\t\t\t MAKE_NOT_CLEAN  : < if true do not support make clean commands > ,"
	echo -e "\t\t\t MAKE_OPTION     : < make build option > ,"
	echo -e "\t\t\t RESULT_FILE     : < make built images to copy resultdir, to support multiple file, the separator is';' > ,"
	echo -e "\t\t\t RESULT_NAME     : < copy names to RESULT_DIR, to support multiple name, the separator is';' > ,"
	echo -e "\t\t\t MAKE_JOBS       : < make build jobs number (-j n) > ,"
	echo -e "\t\t\t SCRIPT_PREV     : < previous build script before make build. > ,"
	echo -e "\t\t\t SCRIPT_POST     : < post build script after make build before copy 'RESULT_FILE' done. > ,"
	echo -e "\t\t\t SCRIPT_LATE     : < late build script after copy 'RESULT_FILE' done. > ,"
	echo -e "\t\t\t SCRIPT_CLEAN    : < clean script for clean command. > \","
}

function usage() {
	echo ""
	echo " Usage:"
	echo -e "\t$(basename "$0") -f config.sh [options]"
	echo -e "\t$(basename "$0") menuconfig [-d]\n"
	print_format
	echo ""
	echo " options:"
	echo -e  "\t-t\t select build targets, '<TARGET>' ..."
	echo -e  "\t-c\t run command"
	echo -e  "\t\t support 'cleanbuild','rebuild' and commands supported by target"
	echo -e  "\t-C\t clean all targets, this option run make clean/distclean and 'SCRIPT_CLEAN'"
	echo -e  "\t-i\t show target configs info"
	echo -e  "\t-l\t listup targets"
	echo -e  "\t-j\t set build jobs"
	echo -e  "\t-o\t set build options"
	echo -e  "\t-e\t edit build config file"
	echo -e  "\t-v\t show build log"
	echo -e  "\t-V\t show build log and enable external shell tasks tracing (with 'set -x')"
	echo -ne "\t-s\t build stage :"
	for i in "${!BUILD_STAGE[@]}"; do
		echo -n " '$i'";
	done
	echo -e  "\n\t\t stage order : prev > make > post > copy > late"
	echo -e  "\t-m\t build manual targets 'BUILD_MANUAL'"
	echo -e  "\t-A\t Full build including manual build"
	echo ""
	echo " menuconfig:"
	echo -e  "\t Select the script with the prefix '$BUILD_CONFIG_PREFIX' in the configs directory."
	echo -e  "\t-D\t set search scripts directory for the menuconfig"
	echo ""
}

function err () { echo -e "\033[0;31m$*\033[0m"; }
function msg () { echo -e "\033[0;33m$*\033[0m"; }

BUILD_CONFIG_SCRIPT=""		# build config script file
BUILD_CONFIG_IMAGE=()		# store $BUILD_IMAGES

BUILD_RUN_TARGET=()
BUILD_COMMAND=""
BUILD_CLEANALL=false
BUILD_OPTION=""
BUILD_JOBS="$(grep -c processor /proc/cpuinfo)"
BUILD_TARGET_MANULA=false
BUILD_TARGET_ALL=false

SHOW_INFO=false
SHOW_LIST=false
EDIT=false
DBG_VERBOSE=false
DBG_TRACE=false

function show_build_time () {
	local hrs=$(( SECONDS/3600 ));
	local min=$(( (SECONDS-hrs*3600)/60));
	local sec=$(( SECONDS-hrs*3600-min*60 ));
	printf "\n Total: %d:%02d:%02d\n" $hrs $min $sec
}

BUILD_PROGRESS_PID=""
function show_progress () {
	local spin='-\|/' pos=0
	local delay=0.3 start=$SECONDS
	while true; do
		local hrs=$(( (SECONDS-start)/3600 ));
		local min=$(( (SECONDS-start-hrs*3600)/60));
		local sec=$(( (SECONDS-start)-hrs*3600-min*60 ))
		pos=$(( (pos + 1) % 4 ))
		printf "\r\t: Progress |${spin:$pos:1}| %d:%02d:%02d" $hrs $min $sec
		sleep $delay
	done
}

function run_progress () {
	kill_progress
	show_progress &
	echo -en " $!"
	BUILD_PROGRESS_PID=$!
}

function kill_progress () {
	local pid=$BUILD_PROGRESS_PID
	if pidof $pid; then return; fi
	if [[ $pid -ne 0 ]] && [[ -e /proc/$pid ]]; then
		kill "$pid" 2> /dev/null
		wait "$pid" 2> /dev/null
		echo ""
	fi
}

trap kill_progress EXIT

function print_env () {
	echo -e "\n\033[1;32m BUILD STATUS       = $BUILD_CONFIG_STATUS\033[0m";
	echo -e "\033[1;32m BUILD CONFIG       = $BUILD_CONFIG_SCRIPT\033[0m";
	echo ""
	for key in "${!BUILD_CONFIG_ENV[@]}"; do
		[[ -z ${BUILD_CONFIG_ENV[$key]} ]] && continue;
		message=$(printf " %-18s = %s\n" "$key" "${BUILD_CONFIG_ENV[$key]}")
		msg "$message"
	done
}

function parse_env () {
	for key in "${!BUILD_CONFIG_ENV[@]}"; do
		local val=""
		for i in "${BUILD_CONFIG_IMAGE[@]}"; do
			if [[ $i = *"$key"* ]]; then
				local elem
				elem="$(echo "$i" | cut -d'=' -f 2-)"
				elem="$(echo "$elem" | cut -d',' -f 1)"
				elem="$(echo -e "${elem}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
				val=$elem
				break
			fi
		done
		BUILD_CONFIG_ENV[$key]=$val
	done

	if [[ -z ${BUILD_CONFIG_ENV["RESULT_DIR"]} ]]; then
		BUILD_CONFIG_ENV["RESULT_DIR"]="$(realpath "$(dirname "${0}")")/result"
	fi
	BUILD_LOG_DIR="${BUILD_CONFIG_ENV["RESULT_DIR"]}/$BUILD_LOG_DIR"
}

function setup_env () {
	local path=$1
	[[ -z $path ]] && return;

	path=$(realpath "$(dirname "$1")")
	if [[ -z $path ]]; then
		err " No such 'CROSS_TOOL': $(dirname "$1")"
		exit 1
	fi
	export PATH=$path:$PATH
}

function print_target () {
	local target=$1

	echo -e "\n\033[1;32m BUILD TARGET       = $target\033[0m";
	for key in "${!BUILD_CONFIG_TARGET[@]}"; do
		[[ -z "${BUILD_CONFIG_TARGET[$key]}" ]] && continue;
		if [[ "${key}" == "MAKE_PATH" ]]; then
			message=$(printf " %-18s = %s\n" "$key" "$(realpath "${BUILD_CONFIG_TARGET[$key]}")")
		else
			message=$(printf " %-18s = %s\n" "$key" "${BUILD_CONFIG_TARGET[$key]}")
		fi
		msg "$message"
	done
}

function parse_target () {
	local target=$1
	local contents

	# get target's contents
	for i in "${BUILD_CONFIG_IMAGE[@]}"; do
		if [[ $i == *"$target"* ]]; then
			local elem
			elem="$(echo $(echo "$i" | cut -d'=' -f 1) | cut -d' ' -f 1)"
			[[ $target != "$elem" ]] && continue;

			# cut
			elem="${i#*$elem*=}"
			# remove line-feed, first and last blank
			contents="$(echo "$elem" | tr '\n' ' ')"
			contents="$(echo "$contents" | sed 's/^[ \t]*//;s/[ \t]*$//')"
			break
		fi
	done

	# parse contents's elements
	for key in "${!BUILD_CONFIG_TARGET[@]}"; do
		local val=""
		if ! echo "$contents" | grep -qwn "$key"; then
			BUILD_CONFIG_TARGET[$key]=$val
			[[ $key == "BUILD_MANUAL" ]] && BUILD_CONFIG_TARGET[$key]=false;
			continue;
		fi

		val="${contents#*$key}"
		val="$(echo "$val" | cut -d":" -f 2-)"
		val="$(echo "$val" | cut -d"," -f 1)"
		# remove first,last space and set multiple space to single space
		val="$(echo "$val" | sed 's/^[ \t]*//;s/[ \t]*$//')"
		val="$(echo "$val" | sed 's/\s\s*/ /g')"

		BUILD_CONFIG_TARGET[$key]="$val"
	done

	if [[ -n ${BUILD_CONFIG_TARGET["MAKE_PATH"]} ]]; then
		BUILD_CONFIG_TARGET["MAKE_PATH"]=$(realpath "${BUILD_CONFIG_TARGET["MAKE_PATH"]}")
	fi

	if [[ -z ${BUILD_CONFIG_TARGET["MAKE_TARGET"]} ]]; then
		BUILD_CONFIG_TARGET["MAKE_TARGET"]="all"
	fi

	if [[ -z ${BUILD_CONFIG_TARGET["CROSS_TOOL"]} ]]; then
		BUILD_CONFIG_TARGET["CROSS_TOOL"]=${BUILD_CONFIG_ENV["CROSS_TOOL"]};
	fi

	if [[ -z ${BUILD_CONFIG_TARGET["MAKE_JOBS"]} ]];then
		BUILD_CONFIG_TARGET["MAKE_JOBS"]=$BUILD_JOBS;
	fi
}

function parse_target_list () {
	local target_list=()
	local manuals targets

	for str in "${BUILD_CONFIG_IMAGE[@]}"; do
		local val add=true
		str="$(echo "$str" | tr '\n' ' ')"
		val="$(echo "$str" | cut -d'=' -f 1)"
		val="$(echo -e "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

		# skip buil environments"
		for n in "${!BUILD_CONFIG_ENV[@]}"; do
			if [[ $n == "$val" ]]; then
				add=false
				break
			fi
		done

		[[ $add != true ]] && continue;
		[[ $str == *"="* ]] && target_list+=("$val");
	done

	for i in "${BUILD_RUN_TARGET[@]}"; do
		local found=false;
		for n in "${target_list[@]}"; do
			if [[ $i == "$n" ]]; then
				found=true
				break;
			fi
		done
		if [[ $found == false ]]; then
			echo -e  "\n Not support target '$i'"
			echo -ne " Check targets :"
			for t in "${target_list[@]}"; do
				echo -n " $t"
			done
			echo -e "\n"
			exit 1;
		fi
	done

	for t in "${target_list[@]}"; do
		parse_target "$t"
		if [[ ${BUILD_CONFIG_TARGET["BUILD_MANUAL"]} == true ]]; then
			manuals+="$t "
		else
			targets+="$t "
		fi
	done

	if [[ ${#BUILD_RUN_TARGET[@]} -eq 0 ]]; then
		BUILD_RUN_TARGET=($targets)
		[[ $BUILD_TARGET_MANULA == true ]] && BUILD_RUN_TARGET=($manuals);
		[[ $BUILD_TARGET_ALL == true ]] && BUILD_RUN_TARGET=($manuals $targets);
	fi

	if [[ $SHOW_LIST == true ]]; then
		echo -e "\033[1;32m BUILD CONFIG  = $BUILD_CONFIG_SCRIPT\033[0m";
		echo -e "\033[0;33m TARGETS  = $targets\033[0m";
		[[ $manuals ]] && echo -e "\033[0;33m MANUALLY = $manuals\033[0m";
		echo ""
		exit 0;
	fi
}

function exec_shell () {
	local command=$1 target=$2
	local log="$BUILD_LOG_DIR/$target.script.log"
	local ret

	[[ $DBG_TRACE == true ]] && set -x;

	IFS=";"
	for cmd in $command; do
		cmd="$(echo "$cmd" | sed 's/\s\s*/ /g')"
		cmd="$(echo "$cmd" | sed 's/^[ \t]*//;s/[ \t]*$//')"
		cmd="$(echo "$cmd" | sed 's/\s\s*/ /g')"
		fnc=$($(echo $cmd| cut -d' ' -f1) 2>/dev/null | grep -q 'function')
		unset IFS

		msg "\n $> $cmd"
		rm -f "$log"
		[[ $DBG_VERBOSE == false ]] && run_progress;

		if $fnc; then
			if [[ $DBG_VERBOSE == false ]]; then
				$cmd >> "$log" 2>&1
			else
				$cmd
			fi
		else
			if [[ $DBG_VERBOSE == false ]]; then
				bash -c "$cmd" >> "$log" 2>&1
			else
				bash -c "$cmd"
			fi
		fi
		### get return value ###
		ret=$?

		kill_progress
		[[ $DBG_TRACE == true ]] && set +x;
		if [[ $ret -ne 0 ]]; then
			if [[ $DBG_VERBOSE == false ]]; then
				err " ERROR: script '$target':$log\n";
			else
				err " ERROR: script '$target'\n";
			fi
			break;
		fi
	done

	return $ret
}

function exec_make () {
	local command=$1 target=$2
	local log="$BUILD_LOG_DIR/$target.make.log"
	local ret

	command="$(echo "$command" | sed 's/\s\s*/ /g')"
	msg "\n $> make $command"
	rm -f "$log"

	if [[ $DBG_VERBOSE == false ]] && [[ $command != *menuconfig* ]]; then
		run_progress
		make $command >> "$log" 2>&1
	else
		make $command
	fi
	### get return value ###
	ret=$?

	kill_progress
	if [[ $ret -eq 2 ]] && [[ $command != *"clean"* ]]; then
		if [[ $DBG_VERBOSE == false ]]; then
			err " ERROR: make '$target':$log\n";
		else
			err " ERROR: make '$target'\n";
		fi
	else
		ret=0
	fi

	return $ret
}

function script_prev () {
	local target=$1

	if [[ -z ${BUILD_CONFIG_TARGET["SCRIPT_PREV"]} ]] ||
	   [[ $BUILD_CLEANALL == true ]] ||
	   [[ ${BUILD_STAGE["prev"]} == false ]]; then
		return;
	fi

	if ! exec_shell "${BUILD_CONFIG_TARGET["SCRIPT_PREV"]}" "$target"; then
		exit 1;
	fi
}

function make_target () {
	local target=$1
	local command=$BUILD_COMMAND
	local path=${BUILD_CONFIG_TARGET["MAKE_PATH"]}
	local config=${BUILD_CONFIG_TARGET["MAKE_CONFIG"]}
	local opt="${BUILD_CONFIG_TARGET["MAKE_OPTION"]} -j${BUILD_CONFIG_TARGET["MAKE_JOBS"]} "
	local verfile="${path}/.${target}_defconfig"
	local version="BUILD:${config}:${BUILD_CONFIG_TARGET["MAKE_OPTION"]}"
	declare -A mode=(
		["distclean"]=false
		["clean"]=false
		["defconfig"]=false
		["menuconfig"]=false
		)
	local archopt

	if [[ -z $path ]] || [[ ! -d $path ]]; then
		[[ -z $path ]] && return;
		err " Not found 'MAKE_PATH': '${BUILD_CONFIG_TARGET["MAKE_PATH"]}'"
		exit 1;
	fi
	if [[ ${BUILD_STAGE["make"]} == false ]] ||
	   [[ ! -f $path/makefile && ! -f $path/Makefile ]]; then
		return
	fi

	if [[ ${BUILD_CONFIG_TARGET["MAKE_ARCH"]} ]]; then
		archopt="ARCH=${BUILD_CONFIG_TARGET["MAKE_ARCH"]} "
	fi

	if [[ ${BUILD_CONFIG_TARGET["CROSS_TOOL"]} ]]; then
		archopt+="CROSS_COMPILE=${BUILD_CONFIG_TARGET["CROSS_TOOL"]} "
	fi

	[[ -n $BUILD_OPTION ]] && opt+="$BUILD_OPTION";

	# return if MAKE_TARGET is dtb
	if [[ $(echo ${BUILD_CONFIG_TARGET["MAKE_TARGET"]}  | cut -d " " -f1) == *".dtb"* ]]; then
		if [[ $BUILD_CLEANALL == false ]]; then
			archopt+="$(echo ${BUILD_CONFIG_TARGET["MAKE_TARGET"]} | sed 's/[;,]//g') "
			if ! exec_make "-C $path $archopt $opt" "$target"; then
				exit 1
			fi
		fi
		return
	fi

	if [[ $command == clean ]] || [[ $command == cleanbuild ]] ||
	   [[ $command == rebuild ]]; then
		mode["clean"]=true
	fi

	if [[ $command == cleanall ]] ||
	   [[ $command == distclean ]] || [[ $command == rebuild ]]; then
		mode["clean"]=true;
		mode["distclean"]=true;
		[[ -n $config ]] && mode["defconfig"]=true;
	fi

	if [[ $command == defconfig || ! -f $path/.config ]] && [[ -n $config ]]; then
		mode["defconfig"]=true
		mode["clean"]=true;
		mode["distclean"]=true;
	fi

	if [[ $command == menuconfig ]] && [[ -n $config ]]; then
		mode["menuconfig"]=true
	fi

	if [[ ! -e $verfile ]] || [[ $(cat "$verfile") != "$version" ]]; then
		mode["clean"]=true;
		mode["distclean"]=true
		[[ -n $config ]] && mode["defconfig"]=true;

		rm -f "$verfile";
		echo "$version" >> "$verfile";
		sync;
	fi

	# make clean
	if [[ ${mode["clean"]} == true ]]; then
		if [[ ${BUILD_CONFIG_TARGET["MAKE_NOT_CLEAN"]} != true ]]; then
			exec_make "-C $path clean" "$target"
		fi
		if [[ $command == clean ]]; then
			script_clean "$target"
			exit 0;
		fi
	fi

	# make distclean
	if [[ ${mode["distclean"]} == true ]]; then
		if [[ ${BUILD_CONFIG_TARGET["MAKE_NOT_CLEAN"]} != true ]]; then
			exec_make "-C $path distclean" "$target"
		fi
		[[ $command == distclean ]] || [[ $BUILD_CLEANALL == true ]] && rm -f "$verfile";
		[[ $BUILD_CLEANALL == true ]] && return;
		if [[ $command == distclean ]]; then
			script_clean "$target"
			exit 0;
		fi
	fi

	# make defconfig
	if [[ ${mode["defconfig"]} == true ]]; then
		if ! exec_make "-C $path $archopt $config" "$target"; then
			exit 1;
		fi
		[[ $command == defconfig ]] && exit 0;
	fi

	# make menuconfig
	if [[ ${mode["menuconfig"]} == true ]]; then
		exec_make "-C $path $archopt menuconfig" "$target";
		exit 0;
	fi

	# make targets
	if [[ -z $command ]] ||
	   [[ $command == rebuild ]] || [[ $command == cleanbuild ]]; then
		for i in ${BUILD_CONFIG_TARGET["MAKE_TARGET"]}; do
			i="$(echo "$i" | sed 's/[;,]//g') "
			if ! exec_make "-C $path $archopt $i $opt" "$target"; then
				exit 1
			fi
		done
	else
		if ! exec_make "-C $path $archopt $command $opt" "$target"; then
			exit 1
		fi
	fi
}

function script_post () {
	local target=$1

	if [[ -z ${BUILD_CONFIG_TARGET["SCRIPT_POST"]} ]] ||
	   [[ $BUILD_CLEANALL == true ]] ||
	   [[ ${BUILD_STAGE["post"]} == false ]]; then
		return;
	fi

	if ! exec_shell "${BUILD_CONFIG_TARGET["SCRIPT_POST"]}" "$target"; then
		exit 1;
	fi
}

function make_result () {
	local path=${BUILD_CONFIG_TARGET["MAKE_PATH"]}
	local file=${BUILD_CONFIG_TARGET["RESULT_FILE"]}
	local dir=${BUILD_CONFIG_ENV["RESULT_DIR"]}
	local ret=${BUILD_CONFIG_TARGET["RESULT_NAME"]}

	if [[ -z $file ]] || [[ $BUILD_CLEANALL == true ]] ||
	   [[ ${BUILD_STAGE["copy"]} == false ]]; then
		return;
	fi

	if ! mkdir -p "$dir"; then exit 1; fi

	ret=$(echo "$ret" | sed 's/[;,]//g')
	for src in $file; do
		src=$(realpath "$path/$src")
		src=$(echo "$src" | sed 's/[;,]//g')
		dst=$(realpath "$dir/$(echo "$ret" | cut -d' ' -f1)")
		ret=$(echo $ret | cut -d' ' -f2-)
		if [[ $src != *'*'* ]] && [[ -d $src ]] && [[ -d $dst ]]; then
			rm -rf "$dst";
		fi

		msg "\n $> cp -a $src $dst"
		[[ $DBG_VERBOSE == false ]] && run_progress;
		cp -a $src $dst
		kill_progress
	done
}

function script_late () {
	local target=$1

	if [[ -z ${BUILD_CONFIG_TARGET["SCRIPT_LATE"]} ]] ||
	   [[ $BUILD_CLEANALL == true ]] ||
	   [[ ${BUILD_STAGE["late"]} == false ]]; then
		return;
	fi

	if ! exec_shell "${BUILD_CONFIG_TARGET["SCRIPT_LATE"]}" "$target"; then
		exit 1;
	fi
}

function script_clean () {
	local target=$1 command=$BUILD_COMMAND

	[[ -z ${BUILD_CONFIG_TARGET["SCRIPT_CLEAN"]} ]] && return;
	[[ $command != *"clean"* ]] && return;

	if ! exec_shell "${BUILD_CONFIG_TARGET["SCRIPT_CLEAN"]}" "$target"; then
		exit 1;
	fi
}

function build_target () {
	local target=$1

	parse_target "$target"
	print_target "$target"
	[[ $SHOW_INFO == true ]] && return;
	if ! mkdir -p "${BUILD_CONFIG_ENV["RESULT_DIR"]}"; then exit 1; fi
	if ! mkdir -p "$BUILD_LOG_DIR"; then exit 1; fi

	script_prev "$target"
	make_target "$target"
	script_post "$target"
	make_result "$target"
	script_late "$target"
	script_clean "$target"
}

function build_run () {
	parse_target_list
	print_env

	for i in "${BUILD_RUN_TARGET[@]}"; do
		build_target "$i"
	done

	[[ $BUILD_CLEANALL == true ]] &&
	[[ -d $BUILD_LOG_DIR ]] && rm -rf "$BUILD_LOG_DIR";

	show_build_time
}

function setup_config () {
	local config=$1

	if [[ ! -f $config ]]; then
		err " Not selected build scripts in $config"
		exit 1;
	fi

	# include build script file
	source "$config"
	if [[ -z $BUILD_IMAGES ]]; then
		err " Not defined 'BUILD_IMAGES'\n"
		print_format
		exit 1
	fi

	BUILD_CONFIG_IMAGE=("${BUILD_IMAGES[@]}");
}

function store_config () {
	local path=$1 script=$2
	if [[ ! -f $(realpath "$BUILD_CONFIG_STATUS") ]]; then
cat > "$BUILD_CONFIG_STATUS" <<EOF
PATH   = $(realpath "$BUILD_CONFIG_SCRIPT_DIR")
CONFIG =
EOF
	fi

	if [[ -n $path ]]; then
		if [[ ! -d $(realpath "$path") ]]; then
			err " No such directory: $path"
			exit 1;
		fi
		sed -i "s|^PATH.*|PATH = $path|" "$BUILD_CONFIG_STATUS"
	fi
	if [[ -n $script ]]; then
		if [[ ! -f $(realpath "$script") ]]; then
			err " No such script: $path"
			exit 1;
		fi
		sed -i "s/^CONFIG.*/CONFIG = $script/" "$BUILD_CONFIG_STATUS"
	fi
}

function parse_config () {
	local file=$BUILD_CONFIG_STATUS
	local str ret

	[[ ! -f $file ]] && return;

	str=$(sed -n '/^\<PATH\>/p' "$file");
	ret=$(echo "$str" | cut -d'=' -f 2)
	ret=$(echo "$ret" | sed 's/[[:space:]]//g')
	BUILD_CONFIG_SCRIPT_DIR="${ret# *}"

	str=$(sed -n '/^\<CONFIG\>/p' "$file");
	ret=$(echo "$str" | cut -d'=' -f 2)
	ret=$(echo "$ret" | sed 's/[[:space:]]//g')
	BUILD_CONFIG_SCRIPT="$(realpath "$BUILD_CONFIG_SCRIPT_DIR/"${ret# *}"")"
}

function avail_configs () {
	local table=$1	# parse table
	local prefix=$BUILD_CONFIG_PREFIX
	local extension="sh"
	local val value

	if ! cd "$BUILD_CONFIG_SCRIPT_DIR"; then
		err " Not found $BUILD_CONFIG_SCRIPT_DIR"
		exit 1;
	fi

	value=$(find ./ -print \
		2> >(grep -v 'No such file or directory' >&2) | \
		grep -F "./${prefix}" | sort)

	for i in $value; do
		i="$(echo "$i" | cut -d'/' -f2)"
		[[ -n $(echo "$i" | awk -F".${prefix}" '{print $2}') ]] && continue;
		[[ $i == *common* ]] && continue;
		[[ "${i##*.}" != $extension ]] && continue;
		val="${val} $(echo "$i" | awk -F".${prefix}" '{print $1}')"
		eval "$table=(\"${val}\")"
	done
}

function menu_config () {
	local table=$1 string=$2
	local result=$3 # return value
	local select
	local -a entry

	for i in ${table}; do
		stat="OFF"
		entry+=( "$i" )
		entry+=( " " )
		[[ $i == "$(basename "${!result}")" ]] && stat="ON";
		entry+=( "$stat" )
	done

	if ! which whiptail > /dev/null 2>&1; then
		err " Please install the whiptail"
		exit 1
	fi

	select=$(whiptail --title "Target $string" \
		--radiolist "Choose a $string" 0 50 ${#entry[@]} -- "${entry[@]}" \
		3>&1 1>&2 2>&3)
	[[ -z $select ]] && exit 1;

	eval "$result=(\"${select}\")"
}

function menu_save () {
	if ! (whiptail --title "Save/Exit" --yesno "Save" 8 78); then
		exit 1;
	fi
	store_config "" "$BUILD_CONFIG_SCRIPT"
}

function set_build_stage () {
	for i in "${!BUILD_STAGE[@]}"; do
		if [[ $i == "$1" ]]; then
			for n in "${!BUILD_STAGE[@]}"; do
				BUILD_STAGE[$n]=false
			done
			BUILD_STAGE[$i]=true
			return
		fi
	done

	echo -ne "\n\033[1;31m Not Support Stage Command: $i ( \033[0m"
	for i in "${!BUILD_STAGE[@]}"; do
		echo -n "$i "
	done
	echo -e "\033[1;31m)\033[0m\n"
	exit 1;
}

function parse_args () {
	while getopts "f:t:c:Cj:o:s:D:mAilevVh" opt; do
	case $opt in
		f )	BUILD_CONFIG_SCRIPT=$(realpath "$OPTARG");;
		t )	BUILD_RUN_TARGET=("$OPTARG")
			until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [[ -z "$(eval "echo \${$OPTIND}")" ]]; do
				BUILD_RUN_TARGET+=("$(eval "echo \${$OPTIND}")")
				OPTIND=$((OPTIND + 1))
			done
			;;
		c )	BUILD_COMMAND="$OPTARG";;
		m )	BUILD_TARGET_MANULA=true;;
		A )	BUILD_TARGET_ALL=true;;
		C )	BUILD_CLEANALL=true; BUILD_COMMAND="distclean";;
		j )	BUILD_JOBS=$OPTARG;;
		v )	DBG_VERBOSE=true;;
		V )	DBG_VERBOSE=true; DBG_TRACE=true;;
		o )	BUILD_OPTION="$OPTARG";;
		D )	BUILD_CONFIG_SCRIPT_DIR=$(realpath "$OPTARG")
			store_config "$BUILD_CONFIG_SCRIPT_DIR" ""
			exit 0;;
		i ) 	SHOW_INFO=true;;
		l )	SHOW_LIST=true;;
		e )	EDIT=true;
			break;;
		s ) 	set_build_stage "$OPTARG";;
		h )	usage;
			exit 1;;
	        * )	exit 1;;
	esac
	done
}

###############################################################################
# Run build
###############################################################################
if [[ $1 == "menuconfig" ]]; then
	parse_args "${@: 2}"
else
	parse_args "$@"
fi

if [[ -z $BUILD_CONFIG_SCRIPT ]]; then
	avail_list=
	parse_config
	avail_configs avail_list
	if [[ $* == *"menuconfig"* && $BUILD_COMMAND != "menuconfig" ]]; then
		menu_config "$avail_list" "config" BUILD_CONFIG_SCRIPT
		menu_save
		msg "$(sed -e 's/^/ /' < "$BUILD_CONFIG_STATUS")"
		exit 0;
	fi
	if [[ -z $BUILD_CONFIG_SCRIPT ]]; then
		err " Not selected build script in $BUILD_CONFIG_SCRIPT_DIR"
		err " Set build script with -f <script> or menuconfig option"
		exit 1;
	fi
fi

setup_config "$BUILD_CONFIG_SCRIPT"

if [[ "${EDIT}" == true ]]; then
	$EDIT_TOOL "$BUILD_CONFIG_SCRIPT"
	exit 0;
fi

parse_env
setup_env "${BUILD_CONFIG_ENV["CROSS_TOOL"]}"
build_run
