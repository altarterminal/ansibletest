#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -u<user name> -d

Intall tools.
  - shellshoccar

-u: specify the user name (default: $(whoami) = the user name who executes this)
-d: enable dry-run (= only output the playbook and not execute it) (default: disabled)
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_u=$(whoami)
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
    -d)                  opt_d='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr=${arg}
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

readonly IS_DRYRUN=${opt_d}

if [ "${IS_DRYRUN}" = 'no' ]; then
  if ! type ansible-playbook >/dev/null 2>&1; then
    echo "ERROR:${0##*/}: ansible command not found" 1>&2
    exit 1
  fi

  if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
    echo "ERROR:${0##*/}: invalid inventory specified <${opr}>" 1>&2
    exit 1
  fi

  readonly INVENTORY=${opr}
fi

if [ -z "${opt_u}" ]; then
  echo "ERROR:${0##*/}: user name must be specified" 1>&2
  exit 1
fi

readonly USER_NAME=${opt_u}
readonly TEMP_NAME=${TMPDIR:-/tmp}/${0##*/}_$(date '+%Y%m%d_%H%M%S')_XXXXXX

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK=$(mktemp "${TEMP_NAME}")
trap "[ -e ${PLAYBOOK} ] && rm ${PLAYBOOK}" EXIT

#####################################################################
# main routine
#####################################################################

cat <<'EOF'                                                         |
- name: install tools
  hosts: all
  gather_facts: no
  become: yes
  vars:
    user_name: "<<user_name>>"
    tool_dir: "/home/<<user_name>>/Tools"
    download_dir: "/home/<<user_name>>/Tools/download"
    install_dir: "/home/<<user_name>>/Tools/install"
    bash_file: "/home/<<user_name>>/.bashrc"
  tasks:
    - name: check the user exist
      ansible.builtin.shell: |
        id "{{ user_name }}"

    - name: create tool directory
      ansible.builtin.file:
        path: "{{ tool_dir }}"
        state: "directory"
        owner: "{{ user_name }}"
        group: "{{ user_name }}"
        mode: "755"

    - name: create download directory
      ansible.builtin.file:
        path: "{{ download_dir }}"
        state: "directory"
        owner: "{{ user_name }}"
        group: "{{ user_name }}"
        mode: "755"

    - name: create install directory
      ansible.builtin.file:
        path: "{{ install_dir }}"
        state: "directory"
        owner: "{{ user_name }}"
        group: "{{ user_name }}"
        mode: "755"

    - name: remove the old shellshoccar if exists
      ansible.builtin.file:
        path: "{{ download_dir }}/shellshoccar"
        state: "absent"

    - name: clone shellshoccar
      ansible.builtin.git:
        repo: "https://github.com/ShellShoccar-jpn/installer.git"
        dest: "{{ download_dir }}/shellshoccar"

    - name: install shellshoccar
      ansible.builtin.shell: |
        cd {{ download_dir }}/shellshoccar
        chmod +x ./shellshoccar.sh
        ./shellshoccar.sh --prefix={{ install_dir }}/shellshoccar install

    - name: register the path of shellshoccar
      ansible.builtin.blockinfile:
        path: "{{ bash_file }}"
        block: |
          export PATH="{{ install_dir }}/shellshoccar/bin:${PATH}" 
        marker: "# {mark} ANSIBLE MANAGED BLOCK for TOOLS"
EOF

sed 's#<<user_name>>#'"${USER_NAME}"'#'                             |
cat >"${PLAYBOOK}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK}"
else
  ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"
fi
