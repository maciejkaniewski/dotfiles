# Dracula Theme (for Powerlevel10k)
#
# Colors-only override for ~/.p10k.zsh, sourced right after it so it can
# re-typeset just the segment FOREGROUND colors without touching the
# generated layout/config (icons, segment order, separators, etc).

typeset -g POWERLEVEL9K_RULER_FOREGROUND='#6272a4'
typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND='#6272a4'
typeset -g POWERLEVEL9K_DIR_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND='#f8f8f2'
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_DIRENV_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_ASDF_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_RUBY_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_ASDF_PYTHON_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_GOLANG_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_NODEJS_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_ASDF_RUST_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_DOTNET_CORE_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_ASDF_FLUTTER_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_LUA_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_JAVA_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_PERL_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_ERLANG_FOREGROUND='#ff79c6'
typeset -g POWERLEVEL9K_ASDF_ELIXIR_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_ASDF_POSTGRES_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ASDF_PHP_FOREGROUND='#ff79c6'
typeset -g POWERLEVEL9K_ASDF_HASKELL_FOREGROUND='#ffb86c'
typeset -g POWERLEVEL9K_ASDF_JULIA_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_NORDVPN_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_RANGER_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_YAZI_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_NNN_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_LF_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_XPLR_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_VIM_SHELL_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_MIDNIGHT_COMMANDER_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_NIX_SHELL_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_CHEZMOI_SHELL_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_DISK_USAGE_NORMAL_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_DISK_USAGE_WARNING_FOREGROUND='#ffb86c'
typeset -g POWERLEVEL9K_DISK_USAGE_CRITICAL_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_RAM_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_SWAP_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_LOAD_NORMAL_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_LOAD_WARNING_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_LOAD_CRITICAL_FOREGROUND='#ffb86c'
typeset -g POWERLEVEL9K_TODO_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_TIMEWARRIOR_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_TASKWARRIOR_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_LOCAL_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_GLOBAL_FOREGROUND='#ff79c6'
typeset -g POWERLEVEL9K_CPU_ARCH_FOREGROUND='#ffb86c'
typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND='#f8f8f2'
typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_ANACONDA_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_GOENV_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_NODENV_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_NVM_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_NODEENV_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_GO_VERSION_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_RUST_VERSION_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_DOTNET_VERSION_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_PHP_VERSION_FOREGROUND='#ff79c6'
typeset -g POWERLEVEL9K_LARAVEL_VERSION_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_JAVA_VERSION_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_PACKAGE_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_RBENV_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_RVM_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_FVM_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_LUAENV_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_JENV_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_PLENV_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_PERLBREW_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_PHPENV_FOREGROUND='#ff79c6'
typeset -g POWERLEVEL9K_SCALAENV_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_HASKELL_STACK_FOREGROUND='#ffb86c'
typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND='#bd93f9'
typeset -g POWERLEVEL9K_TERRAFORM_OTHER_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_TERRAFORM_VERSION_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_AWS_DEFAULT_FOREGROUND='#ffb86c'
typeset -g POWERLEVEL9K_AWS_EB_ENV_FOREGROUND='#50fa7b'
typeset -g POWERLEVEL9K_AZURE_OTHER_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_GCLOUD_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_DEFAULT_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_TOOLBOX_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_PUBLIC_IP_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_VPN_IP_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_IP_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_PROXY_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_BATTERY_LOW_FOREGROUND='#ff5555'
typeset -g POWERLEVEL9K_BATTERY_DISCONNECTED_FOREGROUND='#f1fa8c'
typeset -g POWERLEVEL9K_WIFI_FOREGROUND='#8be9fd'
typeset -g POWERLEVEL9K_TIME_FOREGROUND='#8be9fd'

# my_git_formatter() in ~/.p10k.zsh hardcodes %76F/%178F/%39F/%196F/%244F
# (256-color codes) for the branch name text itself — those aren't exposed
# as POWERLEVEL9K_* variables, so the FOREGROUND overrides above never
# touched them. Redefine the function here (sourced after ~/.p10k.zsh) with
# the same logic, just swapping in this theme's colors.
function my_git_formatter() {
  emulate -L zsh

  if [[ -n $P9K_CONTENT ]]; then
    typeset -g my_git_format=$P9K_CONTENT
    return
  fi

  if (( $1 )); then
    local       meta='%f'
    local      clean='%F{#50fa7b}'
    local   modified='%F{#f1fa8c}'
    local  untracked='%F{#8be9fd}'
    local conflicted='%F{#ff5555}'
  else
    local       meta='%F{#6272a4}'
    local      clean='%F{#6272a4}'
    local   modified='%F{#6272a4}'
    local  untracked='%F{#6272a4}'
    local conflicted='%F{#6272a4}'
  fi

  local res

  if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
    local branch=${(V)VCS_STATUS_LOCAL_BRANCH}
    (( $#branch > 32 )) && branch[13,-13]="…"
    res+="${clean}${(g::)POWERLEVEL9K_VCS_BRANCH_ICON}${branch//\%/%%}"
  fi

  # Show the tag even when on a branch -- see the same change in ~/.p10k.zsh.
  if [[ -n $VCS_STATUS_TAG ]]; then
    local tag=${(V)VCS_STATUS_TAG}
    (( $#tag > 32 )) && tag[13,-13]="…"
    res+=" ${meta}${(g::)MY_VCS_TAG_ICON}${clean}${tag//\%/%%}"
  fi

  [[ -z $VCS_STATUS_LOCAL_BRANCH && -z $VCS_STATUS_TAG ]] &&
    res+="${meta}@${clean}${VCS_STATUS_COMMIT[1,8]}"

  if [[ -n ${VCS_STATUS_REMOTE_BRANCH:#$VCS_STATUS_LOCAL_BRANCH} ]]; then
    res+="${meta}:${clean}${(V)VCS_STATUS_REMOTE_BRANCH//\%/%%}"
  fi

  if [[ $VCS_STATUS_COMMIT_SUMMARY == (|*[^[:alnum:]])(wip|WIP)(|[^[:alnum:]]*) ]]; then
    res+=" ${modified}wip"
  fi

  if (( VCS_STATUS_COMMITS_AHEAD || VCS_STATUS_COMMITS_BEHIND )); then
    (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ${clean}⇣${VCS_STATUS_COMMITS_BEHIND}"
    (( VCS_STATUS_COMMITS_AHEAD && !VCS_STATUS_COMMITS_BEHIND )) && res+=" "
    (( VCS_STATUS_COMMITS_AHEAD  )) && res+="${clean}⇡${VCS_STATUS_COMMITS_AHEAD}"
  fi

  (( VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" ${clean}⇠${VCS_STATUS_PUSH_COMMITS_BEHIND}"
  (( VCS_STATUS_PUSH_COMMITS_AHEAD && !VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" "
  (( VCS_STATUS_PUSH_COMMITS_AHEAD  )) && res+="${clean}⇢${VCS_STATUS_PUSH_COMMITS_AHEAD}"
  (( VCS_STATUS_STASHES        )) && res+=" ${clean}*${VCS_STATUS_STASHES}"
  [[ -n $VCS_STATUS_ACTION     ]] && res+=" ${conflicted}${VCS_STATUS_ACTION}"
  (( VCS_STATUS_NUM_CONFLICTED )) && res+=" ${conflicted}~${VCS_STATUS_NUM_CONFLICTED}"
  (( VCS_STATUS_NUM_STAGED     )) && res+=" ${modified}+${VCS_STATUS_NUM_STAGED}"
  (( VCS_STATUS_NUM_UNSTAGED   )) && res+=" ${modified}!${VCS_STATUS_NUM_UNSTAGED}"
  (( VCS_STATUS_NUM_UNTRACKED  )) && res+=" ${untracked}${(g::)POWERLEVEL9K_VCS_UNTRACKED_ICON}${VCS_STATUS_NUM_UNTRACKED}"
  (( VCS_STATUS_HAS_UNSTAGED == -1 )) && res+=" ${modified}─"

  typeset -g my_git_format=$res
}
functions -M my_git_formatter 2>/dev/null

typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_COLOR='#50fa7b'
typeset -g POWERLEVEL9K_VCS_LOADING_VISUAL_IDENTIFIER_COLOR='#6272a4'
