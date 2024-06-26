#!/bin/bash

########################
## MAIN CONFIGURATION ##
########################

# Config
HOSTNAME="archlinux"
LOCALE="en_US.UTF-8"

# Packages
PACKAGES_BASE=(base base-devel linux-zen linux-firmware linux-zen-headers sudo)
PACKAGES_BOOT=(os-prober grub efibootmgr dosfstools mtools)
PACKAGES_EXTRA=(git hyfetch htop curl wget mc nano neovim less tldr github-cli networkmanager openssh tmux iwd dhcpcd pavucontrol github-cli wl-clipboard openrgb fzf dotnet-sdk dotnet-runtime aspnet-runtime docker nmap openbsd-netcat dbus-broker-units mkinitcpio)
PACKAGES_GUI=(hyprland hyprpaper kitty alacritty waybar rofi-wayland ttf-firacode-nerd noto-fonts-emoji qt5ct nwg-look kvantum kvantum-qt5 nautilus dolphin xwaylandvideobridge xdg-desktop-portal xdg-desktop-portal-hyprland python-pywal pipewire-pulse pipewire-jack qt6-multimedia-ffmpeg polkit polkit-kde-agent)
PACKAGES_YAY=(google-chrome spotify discord github-desktop-bin jetbrains-toolbox postman-bin wdisplays grimshot imhex-bin)



######################
## HELPER FUNCTIONS ##
######################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
GRAY='\033[1;30m'
NC='\033[0m' # No Color

# Helpers
ensure_root() {
    if [ $# -ne 1 ]; then
        echo -e "\033[1;33mUsage: ensure_root <1|0>\033[0m"  # Yellow for usage instructions
        exit 1
    fi

    if [ "$1" -eq 1 ]; then
        if [ "$(id -u)" -ne 0 ]; then
            echo -e "\033[1;31mThis script must be run as root\033[0m"  # Red for error
            exit 1
        fi
    elif [ "$1" -eq 0 ]; then
        if [ "$(id -u)" -eq 0 ]; then
            echo -e "\033[1;31mThis script must not be run as root\033[0m"  # Red for error
            exit 1
        fi
    else
        echo -e "\033[1;31mInvalid argument: $1\033[0m"  # Red for invalid input
        exit 1
    fi
}

prompt_bool() {
    local prompt="$1"
    local default_answer="$2"
    local response

    # Convert default_answer to lowercase for consistency
    default_answer=$(echo "$default_answer" | tr '[:upper:]' '[:lower:]')

    # Determine the prompt suffix based on the default answer
    if [ "$default_answer" = "y" ]; then
        prompt="$prompt (Y/n)"
    elif [ "$default_answer" = "n" ]; then
        prompt="$prompt (y/N)"
    else
        prompt="$prompt (y/n)"
    fi

    while true; do
        # Prompt the user
        read -p "$prompt " response

        # Convert response to lowercase for consistency
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

        # Check the response
        if [ -z "$response" ] && [ -n "$default_answer" ]; then
            response="$default_answer"
        fi

        if [ "$response" = "y" ]; then
            return 0  # Success / Yes
        elif [ "$response" = "n" ]; then
            return 1  # Failure / No
        else
            echo "Invalid response. Please enter 'y' or 'n'."
        fi
    done
}

select_partition() {
    local prompt="$1"
    local result_var="$2"
    local optional="$3"

    echo -e "${CYAN}$prompt${NC}"  # Display prompt in blue

    local drives=()
    local drive_index=1
    # Only list drives if none is selected yet
    if [ -z "$SELECTED_DRIVE" ]; then
        while IFS=' ' read -r name size type; do
            if [ $type = "disk" ]; then
                echo -e "${CYAN}    $drive_index) ${GRAY}/dev/$name: ${YELLOW}$size${NC}"
                drives+=("/dev/$name")
                drive_index=$((drive_index+1))
            fi
        done < <(lsblk -lno NAME,SIZE,TYPE | grep "disk")

        if [ "$optional" = "1" ]; then
            drives+=("(none)")
            echo -e "${YELLOW}    $drive_index) (none)${NC}"  # Display '(none)' in yellow
            drive_index=$((drive_index+1))
        else
            drive_index=$((drive_index-1))
        fi

        local drive_selection
        while true; do
            echo -e -n "${BRIGHT_CYAN}Select drive (1..$drive_index): ${NC}"
            read drive_selection
            if [[ $drive_selection =~ ^[0-9]+$ ]] && [ $drive_selection -ge 1 ] && [ $drive_selection -le $drive_index ]; then
                if [ "$optional" = "1" ] && [ $drive_selection -eq $drive_index ]; then
                    declare -g "$result_var=(none)"
                    return
                else
                    SELECTED_DRIVE="${drives[$((drive_selection-1))]}"
                fi
                break
            else
                echo -e "${RED}Invalid selection, please try again.${NC}"  # Red for error message
            fi
        done
    fi

    # Select partition from the selected drive
    local partitions=()
    local partition_index=1
    while IFS=' ' read -r dev size type fstype mountpoint; do
        if [[ $type == "part" ]]; then
            local label=""
            local highlight="${GREEN}"  # Green for partitions
	    local dev_color="${GRAY}"
            if [[ "/dev/$dev" == "$DEV_EFI" ]]; then
                label=" (EFI)"
		dev_color="${GREEN}"
            elif [[ "/dev/$dev" == "$DEV_ROOT" ]]; then
                label=" (Root)"
		dev_color="${GREEN}"
            elif [[ "/dev/$dev" == "$DEV_SWAP" ]]; then
                label=" (Swap)"
		dev_color="${GREEN}"
            fi

            echo -e "${CYAN}    $partition_index) ${dev_color}/dev/${dev}: ${YELLOW}$size, ${MAGENTA}$fstype${GREEN}${label}${NC}"
            partitions+=("/dev/$dev")
            partition_index=$((partition_index+1))
        fi
    done < <(lsblk -lno NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT $SELECTED_DRIVE | grep "part")

    if [ "$optional" = "1" ]; then
        partitions+=("(none)")
        echo -e "${YELLOW}    $partition_index) (none)${NC}"  # Display '(none)' in yellow
    else
        partition_index=$((partition_index-1))
    fi

    local partition_selection
    while true; do
        echo -e -n "${BRIGHT_CYAN}Select partition (1..$partition_index, or 'b' to go back): ${NC}"
        read partition_selection
        if [[ $partition_selection == 'b' ]]; then
            SELECTED_DRIVE=""  # Reset drive selection on back
            select_partition "$prompt" "$result_var" "$optional"
            return
        elif [[ $partition_selection =~ ^[0-9]+$ ]] && [ $partition_selection -ge 1 ] && [ $partition_selection -le $partition_index ]; then
            break
        elif [ "$optional" = "1" ] && [ $partition_selection -eq $partition_index ]; then
            declare -g "$result_var=(none)"
            return
        else
            echo -e "${RED}Invalid selection, please try again.${NC}"
        fi
    done

    # Set the result variable globally
    declare -g "$result_var=${partitions[$((partition_selection-1))]}"
}

select_timezone() {
    if [[ -n "$TIMEZONE" && -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
        echo -e "${GREEN}Timezone already set to: $TIMEZONE${NC}"
        return 0
    fi

    local continent city continent_path city_path matches
    while true; do
        echo -e "${CYAN}Select a continent (enter '?' to list all valid options):${NC}"
        read continent
        if [[ "$continent" == "?" ]]; then
            echo -e "${YELLOW}Available Continents:${NC}"
            find /usr/share/zoneinfo -mindepth 1 -maxdepth 1 -type d | rev | cut -d '/' -f 1 | rev | grep '^[A-Z]' | column
            continue
        fi

        matches=$(find /usr/share/zoneinfo -mindepth 1 -maxdepth 1 -type d | rev | cut -d '/' -f 1 | rev | grep -i "^$continent" | wc -l)
        if (( matches == 1 )); then
            continent=$(find /usr/share/zoneinfo -mindepth 1 -maxdepth 1 -type d | rev | cut -d '/' -f 1 | rev | grep -i "^$continent")
        else
            echo -e "${RED}Invalid or ambiguous continent. Please try again.${NC}"
            continue
        fi

        continent_path="/usr/share/zoneinfo/$continent"
        while true; do
            echo -e "${CYAN}Select a city from $continent (enter '?' for options, 'back' to select another continent):${NC}"
            read city
            if [[ "$city" == "back" ]]; then
                break
            elif [[ "$city" == "?" ]]; then
                echo -e "${YELLOW}Available Cities in $continent:${NC}"
                find "$continent_path" -mindepth 1 -maxdepth 1 -type f | rev | cut -d '/' -f 1 | rev | grep '^[A-Z]' | column
                continue
            fi

            matches=$(find "$continent_path" -mindepth 1 -maxdepth 1 -type f | rev | cut -d '/' -f 1 | rev | grep -i "^$city" | wc -l)
            if (( matches == 1 )); then
                city=$(find "$continent_path" -mindepth 1 -maxdepth 1 -type f | rev | cut -d '/' -f 1 | rev | grep -i "^$city")
            else
                echo -e "${RED}Invalid or ambiguous city. Please try again.${NC}"
                continue
            fi

            city_path="$continent_path/$city"
            if [[ -f "$city_path" ]]; then
                echo -e "${GREEN}You have selected the timezone: $continent/$city${NC}"
                if prompt_bool "Is this correct?" "y"; then
                    declare -g TIMEZONE="$continent/$city"
                    return 0
                else
                    echo -e "${RED}Please try again.${NC}"
                fi
            else
                echo -e "${RED}Invalid city. Please try again.${NC}"
            fi
        done
    done
}

is_valid_username() {
	local username="$1"
	if [[ "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
		return 0  # valid
	else
		return 1  # invalid
	fi
}

is_host_vmware() {
    # Check if running inside VMware
    sudo dmidecode -s system-manufacturer 2>/dev/null | grep -iq "VMware"
}

check_network_access() {
    # Ping a reliable server to check for internet connectivity
    ping -c 1 1.1.1.1 > /dev/null 2>&1
    local net_status=$?

    if [ $net_status -ne 0 ]; then
        echo -e "${RED}Network check failed: No internet connection.${NC}"  # Red for failure
        exit 1
    else
        echo -e "${GREEN}Network check successful: Internet connection verified.${NC}"  # Green for success
    fi
}

detect_nvidia() {
    if [[ -n "$NVIDIA" ]]; then
        echo -e "${YELLOW}NVIDIA variable is already set to: $NVIDIA${NC}"
        return 0
    fi

    if lspci | grep -qi nvidia; then
        NVIDIA=1
        echo -e "${GREEN}NVIDIA GPU detected. NVIDIA variable set to 1.${NC}"
    else
        NVIDIA=0
        echo -e "${YELLOW}No NVIDIA GPU detected. NVIDIA variable set to 0.${NC}"
    fi
}

detect_razer() {
    if lsusb | grep -q "1532:"; then
        echo -e "${GREEN}Razer device detected. Installing openrazer-daemon.${NC}"
        sudo pacman -S openrazer-daemon
    else
        echo -e "${YELLOW}No Razer devices detected.${NC}"
    fi
}

enable_ssh() {
	echo Port 22 >> /etc/ssh/sshd_config
	echo AddressFamily any >> /etc/ssh/sshd_config
	echo ListenAddress 0.0.0.0 >> /etc/ssh/sshd_config
	echo PermitRootLogin yes >> /etc/ssh/sshd_config
	echo PasswordAuthentication yes >> /etc/ssh/sshd_config
	echo PermitEmptyPasswords yes >> /etc/ssh/sshd_config
		
	systemctl stop sshd
	systemctl enable --now sshd
	
	local ip_address=$(ip route get 1.1.1.1 | awk '{print $7}' | grep -E '.+')
	echo -e "${CYAN}Root SSH access enabled, IP address: ${YELLOW}$ip_address${NC}"
}

set_root_login_prompt() {
	local username="$1"
	local command="$2"
	
	if [ -z "$username" ] || [ -z "$command" ]; then
		echo "Usage: set_root_login_prompt <username> <command>"
		return 1
	fi

	local service_name="custom-login-prompt"

	# Create a systemd service file
	mkdir -p /etc/systemd/system/getty@tty1.service.d/
	cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $username %I $TERM

EOF

	local user_home=$(eval echo ~$username)
	local profile_file="$user_home/.bash_profile"
	echo "$command" > $profile_file
	chmod +x $profile_file
		
	cat <<EOF | sudo tee $profile_file >/dev/null
echo "Launching post-install script... "
sudo chmod +x /installer/archinstall.sh
ENV_USER=1 /installer/archinstall.sh
echo "Done!"

EOF

	echo "Custom login prompt set successfully."
}

revert_root_login_prompt() {
	set +e
    sudo rm /etc/systemd/system/getty@tty1.service.d/autologin.conf
	sudo truncate -s 0 ~/.bash_profile
	set -e
}

grub_add_cmdline() {
    local option=$1
    local key=${option%%=*}
    local value=${option#*=}

    local grub_path="/etc/default/grub"

    # Backup the original grub file
    cp $grub_path ${grub_path}.bak

    # Extract the current GRUB_CMDLINE_LINUX_DEFAULT value
    current_cmdline=$(grep -oP '(?<=^GRUB_CMDLINE_LINUX_DEFAULT=")[^"]*' $grub_path)

    # Remove the existing option if it exists
    updated_cmdline=$(echo "$current_cmdline" | sed -E "s/(^| )$key=[^ ]*//g")

    # Add the new option
    updated_cmdline="$updated_cmdline $option"
    updated_cmdline=$(echo "$updated_cmdline" | sed 's/^ *//;s/ *$//')

    # Replace the GRUB_CMDLINE_LINUX_DEFAULT line in the grub file
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$updated_cmdline\"/" $grub_path
}

grub_remove_cmdline() {
    local key=$1

    local grub_path="./etc/default/grub"

    # Backup the original grub file
    cp $grub_path ${grub_path}.bak

    # Extract the current GRUB_CMDLINE_LINUX_DEFAULT value
    current_cmdline=$(grep -oP '(?<=^GRUB_CMDLINE_LINUX_DEFAULT=")[^"]*' $grub_path)

    # Remove the specified key (both key-only and key=value pairs)
    updated_cmdline=$(echo "$current_cmdline" | sed -E "s/(^| )$key(=[^ ]*)?( |$)//g")
    updated_cmdline=$(echo "$updated_cmdline" | sed 's/^ *//;s/ *$//')

    # Replace the GRUB_CMDLINE_LINUX_DEFAULT line in the grub file
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$updated_cmdline\"/" $grub_path
}

mkinitcpio_insert_module() {
    local module=$1
    local index=$2

    local mkinitcpio_conf="./etc/mkinitcpio.conf"

    # Backup the original mkinitcpio.conf file
    cp "$mkinitcpio_conf" "$mkinitcpio_conf.bak"

    # Extract the current MODULES array
    current_modules=$(grep -oP '(?<=^MODULES=\()[^)]*' "$mkinitcpio_conf")

    # Convert current MODULES string to array
    IFS=' ' read -r -a modules_array <<< "$current_modules"

    # Calculate the insertion index if it's negative
    if [ $index -lt 0 ]; then
        index=$(( ${#modules_array[@]} + index + 1 ))
    fi

    # Insert the module into the array
    modules_array=("${modules_array[@]:0:$index}" "$module" "${modules_array[@]:$index}")

    # Convert the array back to a string
    updated_modules="${modules_array[*]}"

    # Replace the MODULES array in the mkinitcpio.conf file
    sed -i "s/^MODULES=(.*)/MODULES=( ${updated_modules} )/" "$mkinitcpio_conf"
}

mkinitcpio_remove_module() {
    local module=$1

    local mkinitcpio_conf="./etc/mkinitcpio.conf"

    # Backup the original mkinitcpio.conf file
    cp "$mkinitcpio_conf" "$mkinitcpio_conf.bak"

    # Extract the current MODULES array
    current_modules=$(grep -oP '(?<=^MODULES=\()[^)]*' "$mkinitcpio_conf")

    # Convert current MODULES string to array
    IFS=' ' read -r -a modules_array <<< "$current_modules"

    # Remove the specified module from the array
    for i in "${!modules_array[@]}"; do
        if [ "${modules_array[$i]}" == "$module" ]; then
            unset 'modules_array[$i]'
        fi
    done

    # Convert the array back to a string
    updated_modules="${modules_array[*]}"

    # Replace the MODULES array in the mkinitcpio.conf file
    sed -i "s/^MODULES=(.*)/MODULES=( ${updated_modules} )/" "$mkinitcpio_conf"
}



#########################
## INSTALLATION STAGES ##
#########################

# 1. ArchLiveInstaller
arch_install_live() {
	echo -e "${GREEN}Hello from arch_install_live()${NC}"
	ensure_root 1
	
	# Enable remote SSH access
	enable_ssh
	
	# Update pacman
	echo -e "${YELLOW}Updating installer packages...${NC}"
	output=$(pacman -Sy --noconfirm 2>&1)
	if [ $? -ne 0 ]; then
		echo -e "${RED}Failed to update installer packages.${NC}"
		echo "$output"
		exit 1
	fi
	
	# Select partitions: EFI, ROOT, SWAP
	NOSWAP="?"
	select_partition "Select the target EFI partition" DEV_EFI 0
	select_partition "Select the target ROOT partition" DEV_ROOT 0
	select_partition "Select the target SWAP partition" DEV_SWAP 1
	
	if [ "$DEV_SWAP" = "(none)" ]; then
		NOSWAP=1
	fi
	
	if [[ "$DEV_EFI" == "$DEV_ROOT" || "$DEV_EFI" == "$DEV_SWAP" || ("$DEV_SWAP" != "(none)" && "$DEV_ROOT" == "$DEV_SWAP") ]]; then
		echo -e "${RED}Error: Selected partitions must be unique.${NC}"
		exit 1
	fi

	# Verify partition sizes
	local par_size_efi=$(lsblk -b -o SIZE -n "$DEV_EFI")
	if [[ $par_size_efi -lt $((260 * 1024 * 1024)) || $par_size_efi -gt $((990 * 1024 * 1024)) ]]; then
		echo -e "${RED}Error: The EFI partition must be at least 260MB, and no more than 990MB.${NC}"
		exit 1
	fi
	
	local par_size_root=$(lsblk -b -o SIZE -n "$DEV_ROOT")
	if [[ $par_size_root -lt $((20 * 1024 * 1024 * 1024)) ]]; then
		echo -e "${RED}Error: The ROOT partition must be at least 20GB.${NC}"
		exit 1
	fi
	
	if [ "$NOSWAP" != "1" ]; then
		local par_size_swap=$(lsblk -b -o SIZE -n "$DEV_SWAP")
		local ram_size=$(free | grep Mem | awk '{print $7}')
		local swap_confirm=0
		if [[ $par_size_swap -lt $((256 * 1024 * 1024)) ]]; then
			swap_confirm=1
			echo "${YELLOW}The SWAP partition should be at least 256MB.${NC}"
		elif [[ $par_size_swap -gt $(($ram_size+(1024 * 1024 * 1024 * 1024))) ]]; then
			swap_confirm=1
			echo "${YELLOW}The SWAP partition's size shouldn't exceed the total RAM size.${NC}"
		fi
		
		if [ $swap_confirm -eq 1 ]; then
			if ! prompt_bool "${YELLOW}Continue with the selected SWAP size layout?${NC}" "n"; then
				echo -e "${RED}Aborting${NC}"
				exit
			fi
		fi
	fi
	
	echo -e "${CYAN}Partitioning summary:${NC}"
	echo -e "   ${GREEN}EFI:${NC} $DEV_EFI"
	echo -e "   ${GREEN}ROOT:${NC} $DEV_ROOT"
	if [ "$NOSWAP" != "1" ]; then
		echo -e "   ${GREEN}SWAP:${NC} $DEV_SWAP"
	else
		echo -e "   ${GREEN}SWAP:${NC} (none)"
	fi
	
	if ! prompt_bool "Continue with the selected partitioning layout?" "n"; then
		echo -e "${RED}Aborting${NC}"
		exit
	fi

	# Unmount partitions
	set +e
	umount -lR /mnt > /dev/null 2>&1
	swapoff $DEV_SWAP > /dev/null 2>&1
	set -e
	
	# Format partitions
	echo -e "${YELLOW}Formatting EFI partition...${NC}"
	mkfs.fat -F32 $DEV_EFI

	echo -e "${YELLOW}Formatting ROOT partition...${NC}"
	mkfs.btrfs -f $DEV_ROOT

	if [ "$NOSWAP" -ne "1" ]; then
		echo -e "${YELLOW}Formatting SWAP partition...${NC}"
		mkswap $DEV_SWAP
	fi
	
	# Mount partitions
	echo -e "${YELLOW}Mounting system partitions...${NC}"
	mount $DEV_ROOT /mnt
	mkdir /mnt/boot
	mount $DEV_EFI /mnt/boot
	[ "$NOSWAP" -ne "1" ] && swapon $DEV_SWAP	
	
	# Bootstrap Arch
	echo -e "${YELLOW}Bootstrapping Arch...${NC}"
	PACKAGES=("${PACKAGES_BASE[@]}" "${PACKAGES_BOOT[@]}" "${PACKAGES_EXTRA[@]}")
	yes | pacstrap -i /mnt "${PACKAGES[@]}"
	genfstab -U /mnt >> /mnt/etc/fstab
	
	# Move this script to /mnt/installer
	mkdir -p /mnt/installer
	SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )/"$(basename "$0")
	if [[ "$SCRIPT_PATH" =~ ^/proc/* ]]; then
		curl -sL sparky.codes/arch > /mnt/installer/archinstall.sh
	else
		cp "$SCRIPT_PATH" /mnt/installer/archinstall.sh
	fi
	
	chmod +x /mnt/installer/archinstall.sh
	
	# Transfer wifi connection data, if any
	if [ -d /var/lib/iwd/ ]; then
		iwd_data=$(find /var/lib/iwd -type f -name "*.psk" | head -n 1)
		if [ ! -z "$iwd_data" ] && [ -f "$iwd_data" ]; then
			mkdir -p /mnt/var/lib/iwd/
			cp "$iwd_data" /mnt/var/lib/iwd/
		fi
	fi
	
	# Chroot into /mnt, execute self with ENV_CHROOT=1
	ENV_CHROOT=1 arch-chroot /mnt /installer/archinstall.sh
	
	# Unmount all in /mnt
	echo -e "${YELLOW}Unmounting all partitions${NC}"
	umount -lR /mnt
	
	# Prompt for reboot
	echo -e "${YELLOW}The system must be rebooted to continue the installation.${NC}"
	
	if prompt_bool "Reboot now?" "y"; then
		reboot now
	else
		echo -e "${GREEN}Exiting without reboot${NC}"
		exit
	fi
}

# 2. ArchLiveChroot
arch_install_chroot() {
    echo -e "${GREEN}Hello from arch_install_chroot()${NC}"
    ensure_root 1

    # Configure root user password
    echo -e "${YELLOW}Enter the root user's password:${NC}"
    until passwd; do
        echo -e "${RED}Password change failed, trying again.${NC}"
    done

    # Prompt for non-root user, configure password
    USER_NAME="root"
    if prompt_bool "Create a new non-root user?" "y"; then
        while true; do
            echo -e "${CYAN}Enter a username: ${NC}"
            read username
            if is_valid_username "$username"; then
                break
            else
                echo -e "${RED}Invalid username. It must start with a letter and can only contain lowercase letters, digits, underscores, and dashes.${NC}"
            fi
        done
        groupadd plugdev
        useradd -m -g users -G wheel,storage,power,video,audio,plugdev -s /bin/bash ${username}
        USER_NAME="${username}"
        echo -e "${YELLOW}Enter ${username}'s password:${NC}"
        until passwd ${username}; do
            echo -e "${RED}Password change failed, trying again.${NC}"
        done
    fi

    # Uncomment "%wheel ALL=(ALL:ALL) ALL" in /etc/sudoers
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    # Synchronize pacman
    echo -e "${YELLOW}Synchronizing package databases and updating packages...${NC}"
    pacman -Syu --noconfirm

    # Configure timezone, locale and hwclock
    echo -e "${CYAN}Configuring system...${NC}"
    select_timezone
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "${HOSTNAME}" > /etc/hostname
    echo -e "127.0.0.1\tlocalhost" >> /etc/hosts
    echo -e "::1\t\tlocalhost" >> /etc/hosts
    echo -e "127.0.1.1\t${HOSTNAME}.localdomain\t${HOSTNAME}" >> /etc/hosts

    # Enable NetworkManager
    echo -e "${GREEN}Enabling NetworkManager...${NC}"
    systemctl enable NetworkManager
    systemctl enable dhcpcd
    systemctl enable sshd

    # Configure GRUB bootloader
    echo -e "${YELLOW}Installing and configuring GRUB bootloader...${NC}"
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Enable [multilib] in /etc/pacman.conf and synchronize pacman
    echo -e "${YELLOW}Enabling [multilib] repository and updating...${NC}"
    echo "[multilib]" >> /etc/pacman.conf
    echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
    pacman -Sy --noconfirm

    # Autolaunch this script in /home/$UNAME/.bash_profile or /root/.bash_profile with ENV_USER=1
	[ ! -z "$USER_NAME" ] && set_root_login_prompt "$USER_NAME" "ENV_USER=1 /installer/archinstall.sh"
}

# 3. TargetUser
arch_install_user() {
	echo -e "${GREEN}Hello from arch_install_user()${NC}"
	ensure_root 0
	revert_root_login_prompt

	sudo mkdir -p /installer/git/
	sudo chown -R $USER /installer
	
	# Miscellaneous stuff
        echo -e "${CYAN}Configuring git default branch to 'master'...${NC}"
        git config --global init.defaultBranch master

	# Install nvidia-all
	detect_nvidia
	if [ "$NVIDIA" = "1" ]; then
		echo -e "${YELLOW}Configuring NVIDIA drivers${NC}"
		cd /installer/git/
		git clone https://github.com/Frogging-Family/nvidia-all.git
		cd nvidia-all
		makepkg -si

		sudo mkdir -p /usr/lib/modprobe.d/
		echo "options nvidia NVreg_UsePageAttributeTable=1 NVreg_InitializeSystemMemoryAllocations=0 NVreg_DynamicPowerManagement=0x02 NVreg_EnableGpuFirmware=0" | sudo tee "/usr/lib/modprobe.d/nvidia.conf" > /dev/null
		echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee -a "/usr/lib/modprobe.d/nvidia.conf" > /dev/null
	fi
	
	# Install yay
	echo -e "${YELLOW}Installing Yay and necessary build tools...${NC}"
	sudo pacman -S --needed base-devel git
	cd /installer/git/
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
	
	# Autodetect and mount Windows EFI partition (WINEFI=1)
	set +e
	echo -e "${YELLOW}Detecting Windows installations...${NC}"
	WINEFI=0
	sudo mkdir -p /mnt/efi
	efi_partitions=$(sudo fdisk -l -oDevice,Type | grep "/dev/" | grep -vE "^Disk" | grep -i efi | awk '{print $1}')
	for partition in $efi_partitions; do
		sudo umount -lR /mnt/efi
		sudo mount "$partition" /mnt/efi
		if [ $? -eq 0 ]; then
			if [ -d /mnt/efi/EFI/Microsoft/Boot ]; then
				WINEFI=1
				break
			else
				sudo umount -lR /mnt/efi
			fi
		fi
	done
	set -e
	
	# Set GRUB_TIMEOUT=20, GRUB_DISABLE_OS_PROBER=false in /etc/default/grub
	sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=20/' /etc/default/grub
	sudo sed -i 's/^#\(GRUB_DISABLE_OS_PROBER=false\)/\1/' /etc/default/grub
	
	# Regenerate grub config
	echo -e "${YELLOW}Regenerating GRUB config...${NC}"
	sudo grub-mkconfig -o /boot/grub/grub.cfg
	
	# Unmount Windows EFI partition (if WINEFI = 1)
	if [ $WINEFI -eq 1 ]; then
		sudo umount -lR /mnt/efi
		if [ $? -eq 0 ]; then
			sudo rm -rf /mnt/efi
		else
			echo -e "${RED}Failed to delete Windows EFI mount point${NC}"
		fi
	fi
	
	# Add nvidia MODULES, regenerate mkinitcpio
	if [ "$NVIDIA" = "1" ]; then
		set +e
		echo -e "${YELLOW}Adding NVIDIA modules to mkinitcpio...${NC}"
		modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
		mkinitcpio_conf="/etc/mkinitcpio.conf"

		if [ ! -f "$mkinitcpio_conf" ]; then
			echo -e "${RED}Error: $mkinitcpio_conf does not exist.${NC}"
			exit 1
		fi

		sudo cp "$mkinitcpio_conf" "${mkinitcpio_conf}.bak"
		if grep -q "^MODULES=" "$mkinitcpio_conf"; then
			sudo sed -i "/^MODULES=/ s/)/ $modules)/" "$mkinitcpio_conf"
		else
			echo "MODULES=($modules)" | sudo tee -a "$mkinitcpio_conf" > /dev/null
		fi
		echo "Modules added to MODULES in $mkinitcpio_conf."
		
		sudo mkinitcpio -P
		set -e
	fi
	
	# Install core GUI ($PACKAGES_GUI)
	echo -e "${YELLOW}Installing GUI packages...${NC}"
	yes | sudo pacman -Sy "${PACKAGES_GUI[@]}"
	
	detect_razer
	
	yes | yay -S gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus hyprlang hyprcursor hyprwayland-scanner xcb-util-errors
	
	if is_host_vmware; then
		echo -e "${YELLOW}Running inside a VM, installing necessary packages...${NC}"
		sudo pacman -Sy open-vm-tools xf86-video-vmware
		export WLR_RENDERER_ALLOW_SOFTWARE=1
		export WLR_NO_HARDWARE_CURSORS=1
	fi
	
	# Truncate /home/$UNAME/.bash_profile or /root/.bash_profile
	sudo truncate -s 0 ~/.bash_profile
	
	echo -e "${GREEN}Hyprland has been installed, press any key to start it.${NC}"
	echo "To complete this installation, you'll have to run this script from a Hyprland terminal"
	read -p ""
	
	unset ENV_USER
	Hyprland &
}

# 4. TargetPostGui
arch_install_postgui() {
    echo -e "${GREEN}Hello from arch_install_postgui()${NC}"
    ensure_root 0

    # Installing extra software
    echo -e "${YELLOW}Installing additional packages...${NC}"
    yes | yay -Sy "${PACKAGES_YAY[@]}"

	# Remove banner from Hyprland
	cd ~
	sed -i '/autogenerated = 1/s/^/# /' ~/.config/hypr/hyprland.conf
	
    # Update Hyprland PM and add plugins
    echo -e "${YELLOW}Updating Hyprland PM and adding plugin repos...${NC}"
    hyprpm update
    yes | hyprpm add https://github.com/levnikmyskin/hyprland-virtual-desktops
    yes | hyprpm add https://github.com/hyprwm/hyprland-plugins
	hyprpm enable hyprland-virtual-desktops
	hyprpm enable hyprtrails
	hyprpm reload

    # Clone dotfiles repo into .config
    echo -e "${YELLOW}Setting up configuration files...${NC}"
    cd ~
    sudo rm -rf .config
    git clone https://github.com/SparkyTD/dotfiles .config

    # Delete /installer
    echo -e "${RED}Cleaning up installation files...${NC}"
    sudo rm -rf /installer

    # The installation is now complete!
    echo -e "${GREEN}The installation is now complete!${NC}"
}



############################
## INSTALL PHASE SELECTOR ##
############################

# Try to connect to wifi
if [ -d /var/lib/iwd/ ]; then
    iwd_data=$(find /var/lib/iwd -type f -name "*.psk" | head -n 1)
    if [ -f $iwd_data ]; then
        wifi_name=$(basename "$iwd_data" .psk)
        wifi_adapter="wlan0"

        iwctl device $wifi_adapter set-property Powered on
        echo "" | iwctl station $wifi_adapter connect $wifi_name
    fi
fi

# Exit on error
set -e

# Check network access
check_network_access

# Main branch selector
if lsblk | grep loop0 | grep -q archiso; then
	arch_install_live
elif [ "$ENV_CHROOT" = "1" ]; then
	arch_install_chroot
elif [ "$ENV_USER" = "1" ]; then
	arch_install_user
elif [ ! -z "$HYPRLAND_CMD" ]; then
	arch_install_postgui
else
	echo "Unknown environment, aborting."
	exit 1
fi

