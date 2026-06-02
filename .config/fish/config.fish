## Source from conf.d before our fish config
if test -f /usr/share/cachyos-fish-config/conf.d/done.fish
    source /usr/share/cachyos-fish-config/conf.d/done.fish
end


## Set values
## Run fastfetch as welcome message
function fish_greeting
    fastfetch
end

# Format man pages
set -x MANROFFOPT "-c"
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Set settings for https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

## Environment setup
# Apply .profile: use this to put fish compatible .profile stuff in
if test -f ~/.fish_profile
  source ~/.fish_profile
end

# Add ~/.local/bin to PATH
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $PATH
        set -p PATH ~/.local/bin
    end
end

# Add depot_tools to PATH
if test -d ~/Applications/depot_tools
    if not contains -- ~/Applications/depot_tools $PATH
        set -p PATH ~/Applications/depot_tools
    end
end


## Functions
# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
  bind -Minsert ! __history_previous_command
  bind -Minsert '$' __history_previous_command_arguments
else
  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end

# Fish command history
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

# Copy DIR1 DIR2
function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (echo $argv[1] | trim-right /)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

## Useful aliases
# Replace ls with eza
alias ls='eza -al --color=always --group-directories-first --icons' # preferred listing
alias la='eza -a --color=always --group-directories-first --icons'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first --icons'  # long format
alias lt='eza -aT --color=always --group-directories-first --icons' # tree listing
alias l.="eza -a | grep -e '^\.'"                                     # show only dotfiles

# Common use
alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias hw='hwinfo --short'                                   # Hardware Info
alias big="expac -H M '%m\t%n' | sort -h | nl"              # Sort installed packages according to size in MB
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'          # List amount of -git packages

# Localization helper
function __msg
    set locale $LC_MESSAGES
    if test -z "$locale"
        set locale $LANG
    end

    switch $locale
        case 'pt_BR*'
            switch $argv[1]
                case pacman_updates
                    echo "Atualizações dos repositórios oficiais"
                case aur_updates
                    echo "Atualizações AUR"
                case flatpak_updates
                    echo "Atualizações Flatpak"
                case no_official
                    echo "Nenhuma atualização encontrada nos repositórios oficiais."
                case no_aur
                    echo "Nenhuma atualização encontrada no AUR."
                case no_flatpak
                    echo "Flatpak não está instalado."
                case skip_flatpak
                    echo "Flatpak não está instalado; ignorando atualizações Flatpak."
            end

        case '*'
            switch $argv[1]
                case pacman_updates
                    echo "Official repository updates"
                case aur_updates
                    echo "AUR updates"
                case flatpak_updates
                    echo "Flatpak updates"
                case no_official
                    echo "No official repository updates found."
                case no_aur
                    echo "No AUR updates found."
                case no_flatpak
                    echo "Flatpak is not installed."
                case skip_flatpak
                    echo "Flatpak is not installed; skipping Flatpak updates."
            end
    end
end

# Updates official packages, AUR and Flatpaks
function update
    echo
    set_color --bold
    __msg pacman_updates
    set_color normal
    sudo pacman -Syu

    echo
    set_color --bold
    __msg aur_updates
    set_color normal
    paru -Sua

    echo
    set_color --bold
    __msg flatpak_updates
    set_color normal

    if command -q flatpak
        flatpak update
    else
        __msg skip_flatpak
    end
end

# Checks for updates for official packages, AUR and Flatpaks
function upcheck
    function __highlight_updates
        while read -l line
            set parts (string split " -> " $line)

            if test (count $parts) -eq 2
                set left $parts[1]
                set newver $parts[2]

                set tokens (string split " " $left)
                set pkg $tokens[1]
                set oldver $tokens[2]

                echo -n "$pkg "

                set_color red
                echo -n $oldver

                set_color normal
                echo -n " -> "

                set_color green
                echo $newver

                set_color normal
            else
                echo $line
            end
        end
    end

    echo
    set_color --bold
    __msg pacman_updates
    set_color normal

    set official_updates (checkupdates 2>/dev/null)

    if test (count $official_updates) -gt 0
        printf "%s\n" $official_updates | __highlight_updates
    else
        __msg no_official
    end

    echo
    set_color --bold
    __msg aur_updates
    set_color normal

    set aur_updates (paru -Qua 2>/dev/null)

    if test (count $aur_updates) -gt 0
        printf "%s\n" $aur_updates | __highlight_updates
    else
        __msg no_aur
    end

    echo
    set_color --bold
    __msg flatpak_updates
    set_color normal

    if command -q flatpak
        flatpak remote-ls --updates --columns=application,version,branch
    else
        __msg no_flatpak
    end
end

# Get fastest mirrors
alias mirror="sudo cachyos-rate-mirrors"

# Help people new to Arch
alias apt='man pacman'
alias apt-get='man pacman'
alias please='sudo'
alias tb='nc termbin.com 9999'

# Cleanup orphaned packages
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'

# Get the error messages from journalctl
alias jctl="journalctl -p 3 -xb"

# Recent installed packages
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
