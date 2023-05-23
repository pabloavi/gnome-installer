#!/bin/bash

# script to install gnome extensions and configuration from a clean install

# modes:
# - vanilla
# - material shell
modes=("vanilla" "material-shell")
distros=("fedora")

# load config from config.json using jq
# example:
# {
#   "vanilla": {
#     "material-shell": {
#       "extensions": {
#         "material-shell@papyelgringo": true,
#         "window-list@gnome-shell-extensions.gcampax.github.com": false
#       },
#       "dconf": "./dconf-vanilla.ini"
#     }
#   },
#   "material-shell": {
#     "extensions": {
#       "material-shell@papyelgringo": true,
#       "auto-move-windows@gnome-shell-extensions.gcampax.github.com": true,
#     },
#     "dconf": "./dconf-material-shell.ini"
#   }
# }
function load_config() {
	CONFIG_FILE="./config.json"
	if [[ ! -f "$CONFIG_FILE" ]]; then
		echo "Error: config file not found"
		exit 1
	fi

	if [[ -z "$MODE" ]]; then
		MODE="vanilla"
	fi

	EXTENSIONS=$(jq -r ".${MODE}.extensions | to_entries | map(select(.value == true)) | map(.key) | join(\" \")" "$CONFIG_FILE")
	DISABLED_EXTENSIONS=$(jq -r ".${MODE}.extensions | to_entries | map(select(.value == false)) | map(.key) | join(\" \")" "$CONFIG_FILE")
	DCONF_FILE=$(jq -r ".${MODE}.dconf" "$CONFIG_FILE")
	if [[ -z "$EXTENSIONS" || -z "$DCONF_FILE" ]]; then
		echo "Error: invalid config file"
		exit 1
	fi
}

function install() {
	for extension in $EXTENSIONS; do
		gnome-extensions install "$extension"
	done

	for extension in $DISABLED_EXTENSIONS; do
		gnome-extensions install "$extension"
	done
}

function select_mode() {
	gnome-extensions disable "$(gnome-extensions list --enabled | awk '{print $1}')"
	for extension in $EXTENSIONS; do
		gnome-extensions enable "$extension"
	done

	# TODO: install gtk theme
	dconf dump / >/tmp/dconf.ini
	dconf load / <"$DCONF_FILE"
}

# check arguments
# -h --help, -m --mode, -d --distro, -i --install
MODE="vanilla"
DISTRO="fedora"
INSTALL=false
for arg in "$@"; do
	case $arg in
	-h | --help)
		echo "Usage: $0 [-h|--help] [-m|--mode <mode>] [-d|--distro <distro>]"
		echo "  -h --help: show this help message"
		echo "  -m --mode <mode>: set the mode to install (default, vanilla, material-shell)"
		echo "  -d --distro <distro>: set the distro to install (fedora, arch)"
		echo "  -i --install: wether to run installation or selection (both apply for a single mode)"
		exit 0
		;;
	-m | --mode)
		if [[ -z "$2" ]]; then
			echo "Error: no mode specified"
			exit 1
		fi
		# available modes: vanilla, material-shell
		if [[ ! " ${modes[@]} " =~ " $2 " ]]; then
			echo "Error: invalid mode specified"
			exit 1
		fi
		MODE="$2"
		shift
		shift
		;;
	-d | --distro)
		if [[ -z "$2" ]]; then
			echo "Error: no distro specified"
			exit 1
		fi
		# available distros: fedora
		if [[ ! " ${distros[@]} " =~ " $2 " ]]; then
			echo "Error: invalid distro specified"
			exit 1
		fi
		DISTRO="$2"
		shift
		shift
		;;
	-i | --install)
		INSTALL=true
		shift
		;;
	*)
		echo "Error: unknown argument $arg"
		exit 1
		;;
	esac
done

load_config "$MODE"

if [[ "$INSTALL" = true ]]; then
	install
	exit 0
fi

# select mode
select_mode "$MODE"
