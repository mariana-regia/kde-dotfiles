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
                case no_flatpak_updates
                    echo "Nenhuma atualização Flatpak encontrada."
                case aur_helper_missing
                    echo "Nenhum helper AUR suportado encontrado. Instale o paru ou yay."
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
                case no_flatpak_updates
                    echo "No Flatpak updates found."
                case aur_helper_missing
                    echo "No supported AUR helper found. Install paru or yay."
            end
    end
end

function __aur_helper
    if command -q paru
        echo paru
        return 0
    end

    if command -q yay
        echo yay
        return 0
    end

    return 1
end

# Updates official packages, AUR and Flatpaks
function update
    set -l had_error 0
    set -l aur_helper (__aur_helper)

    echo
    set_color --bold
    __msg pacman_updates
    set_color normal
    sudo pacman -Syu
    or set had_error 1

    echo
    set_color --bold
    __msg aur_updates
    set_color normal

    if test -n "$aur_helper"
        $aur_helper -Sua
        or set had_error 1
    else
        __msg aur_helper_missing
        set had_error 1
    end

    echo
    set_color --bold
    __msg flatpak_updates
    set_color normal

    if command -q flatpak
        flatpak update
        or set had_error 1
    else
        __msg skip_flatpak
    end

    return $had_error
end

# Checks for updates for official packages, AUR and Flatpaks
function upcheck
    set -l had_error 0
    set -l aur_helper (__aur_helper)

    function __read_command_output --argument-names cmd no_updates_status
        set -l stdout_file (mktemp)
        set -l stderr_file (mktemp)

        eval $cmd >$stdout_file 2>$stderr_file
        set -l cmd_status $status

        set -l stdout_lines
        set -l stderr_lines

        if test -s $stdout_file
            set stdout_lines (string split "\n" -- (cat $stdout_file))
        end

        if test -s $stderr_file
            set stderr_lines (string split "\n" -- (cat $stderr_file))
        end

        rm -f $stdout_file $stderr_file

        set -g __upcheck_stdout $stdout_lines
        set -g __upcheck_stderr $stderr_lines
        set -g __upcheck_status $cmd_status

        if test $cmd_status -eq 0
            return 0
        end

        if test $cmd_status -eq $no_updates_status
            return 2
        end

        return 1
    end

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

    __read_command_output "checkupdates" 2

    switch $__upcheck_status
        case 0
            if test (count $__upcheck_stdout) -gt 0
                printf "%s\n" $__upcheck_stdout | __highlight_updates
            else
                __msg no_official
            end
        case 2
            __msg no_official
        case '*'
            if test (count $__upcheck_stderr) -gt 0
                printf "%s\n" $__upcheck_stderr >&2
            end
            set had_error 1
    end

    echo
    set_color --bold
    __msg aur_updates
    set_color normal

    if test -n "$aur_helper"
        __read_command_output "$aur_helper -Qua" 1

        switch $__upcheck_status
            case 0
                if test (count $__upcheck_stdout) -gt 0
                    printf "%s\n" $__upcheck_stdout | __highlight_updates
                else
                    __msg no_aur
                end
            case 1
                __msg no_aur
            case '*'
                if test (count $__upcheck_stderr) -gt 0
                    printf "%s\n" $__upcheck_stderr >&2
                end
                set had_error 1
        end
    else
        __msg aur_helper_missing
        set had_error 1
    end

    echo
    set_color --bold
    __msg flatpak_updates
    set_color normal

    if command -q flatpak
        __read_command_output "flatpak remote-ls --updates --columns=application,version,branch" 0

        if test $__upcheck_status -eq 0
            if test (count $__upcheck_stdout) -gt 0
                printf "%s\n" $__upcheck_stdout
            else
                __msg no_flatpak_updates
            end
        else
            if test (count $__upcheck_stderr) -gt 0
                printf "%s\n" $__upcheck_stderr >&2
            end
            set had_error 1
        end
    else
        __msg no_flatpak
    end

    functions -e __read_command_output
    set -e __upcheck_stdout __upcheck_stderr __upcheck_status
    return $had_error
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
