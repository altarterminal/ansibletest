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

readonly IS_DRYRUN="${opt_d}"

if [ "${IS_DRYRUN}" = 'no' ]; then
  if ! type ansible-playbook >/dev/null 2>&1; then
    echo "ERROR:${0##*/}: ansible command not found" 1>&2
    exit 1
  fi

  if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
    echo "ERROR:${0##*/}: invalid inventory specified <${opr}>" 1>&2
    exit 1
  fi

  readonly INVENTORY="${opr}"
fi

if [ -z "${opt_u}" ]; then
  echo "ERROR:${0##*/}: user name must be specified" 1>&2
  exit 1
fi

readonly USER_NAME="${opt_u}"
readonly TEMP_NAME="${TMPDIR:-/tmp}/${0##*/}_$(date '+%Y%m%d_%H%M%S')_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK="$(mktemp "${TEMP_NAME}")"
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
  tasks:
    - name: check the user exist
      ansible.builtin.shell: |
        id "{{ user_name }}"

    - name: get home directory
      ansible.builtin.shell: "echo ${HOME}"
      register: result
      become_user: "{{ user_name }}"

    - name: set home directory parameter
      ansible.builtin.set_fact:
        home_dir: "{{ result.stdout }}"

    - name: set parameters
      ansible.builtin.set_fact:
        download_dir: "{{ home_dir }}/Tools/download"
        install_dir: "{{ home_dir }}/Tools/install"
        bash_file: "{{ home_dir }}/.bashrc"

    - name: create directories
      ansible.builtin.file:
        path: "{{ item }}"
        state: "directory"
      loop:
        - "{{ download_dir }}"
        - "{{ install_dir }}"
      become_user: "{{ user_name }}"

    - name: remove the old shellshoccar if exists
      ansible.builtin.file:
        path: "{{ download_dir }}/shellshoccar"
        state: "absent"

    - name: clone shellshoccar
      ansible.builtin.git:
        repo: "https://github.com/ShellShoccar-jpn/installer.git"
        dest: "{{ download_dir }}/shellshoccar"
      become_user: "{{ user_name }}"

    - name: install shellshoccar
      ansible.builtin.shell: |
        cd {{ download_dir }}/shellshoccar
        chmod +x ./shellshoccar.sh
        ./shellshoccar.sh --prefix={{ install_dir }}/shellshoccar install
      become_user: "{{ user_name }}"

    - name: register the path of shellshoccar
      ansible.builtin.blockinfile:
        path: "{{ bash_file }}"
        block: |
          export PATH="{{ install_dir }}/shellshoccar/bin:${PATH}" 
        marker: "# {mark} ANSIBLE MANAGED BLOCK for TOOLS"
      become_user: "{{ user_name }}"
EOF

sed 's#<<user_name>>#'"${USER_NAME}"'#'                             |
cat >"${PLAYBOOK}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK}"
else
  ANSIBLE_PIPELINING=1 ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"
fi
