#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -u<user name> -k<key path> -j<host ledger> -d

Setup public key login.

-u: Specify the user name (default: <$(whoami)> = the user name who executes this).
-k: Specify the key path (default: ${HOME}/.ssh/id_rsa).
-j: Specify the json file on which hostname and its ip address are for login target (default: ./host_ledger.json).
-d: Enable dry-run (default: disabled).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_u="$(whoami)"
opt_k="${HOME}/.ssh/id_rsa"
opt_j='./host_ledger.json'
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
    -k*)                 opt_k=${arg#-k}      ;;
    -j*)                 opt_j=${arg#-j}      ;;
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

  readonly INVENTORY_FILE="${opr}"
fi

if [ -z "${opt_u}" ]; then
  echo "ERROR:${0##*/}: user name must be specified" 1>&2
  exit 1
fi

if [ ! -f "${opt_k%.pub}" ]     || [ ! -r "${opt_k%.pub}" ] ||
   [ ! -f "${opt_k%.pub}.pub" ] || [ ! -r "${opt_k%.pub}.pub" ]; then
  echo "ERROR:${0##*/}: invalid key specified <${opt_k}>" 1>&2
  exit 1
fi

if [ ! -f "${opt_j}" ] || [ ! -r "${opt_j}" ]; then
  echo "ERROR:${0##*/}: invalid ledger specified <${opt_j}>" 1>&2
  exit 1
fi

readonly USER_NAME="${opt_u}"
readonly KEY_PATH="$(realpath "${opt_k%.pub}")"
readonly HOST_LEDGER_FILE="${opt_j}"

readonly TEMP_NAME="${TMPDIR:-/tmp}/${0##*/}_$(date '+%Y%m%d_%H%M%S')_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_FILE="$(mktemp "${TEMP_NAME}")"
trap "[ -e ${PLAYBOOK_FILE} ] && rm ${PLAYBOOK_FILE}" EXIT

#####################################################################
# main routine
#####################################################################

cat <<'EOF'                                                         |
- name: setup public key login
  hosts: all
  gather_facts: no
  become: yes
  vars:
    user_name: "<<user_name>>"
    public_key: "<<key_path>>.pub"
    secret_key: "<<key_path>>"
  tasks:
    - name: check the user exist
      ansible.builtin.shell: |
        id "{{ user_name }}"
      register: check_result
      failed_when: check_result.rc not in [0, 1]

    - name: exec setup
      when: check_result.rc == 0
      block:
        - name: get home directory
          ansible.builtin.shell: "echo ${HOME}"
          register: get_result
          become_user: "{{ user_name }}"

        - name: set parameter
          ansible.builtin.set_fact:
            ssh_dir: "{{ get_result.stdout }}/.ssh"
            ssh_key_file: "{{ get_result.stdout }}/.ssh/{{ secret_key | basename }}"
            ssh_config_file: "{{ get_result.stdout }}/.ssh/config"
            known_hosts_file: "{{ get_result.stdout }}/.ssh/known_hosts"

        - name: create ssh directory
          ansible.builtin.file:
            path: "{{ ssh_dir }}"
            state: "directory"
            mode: "755"
          become_user: "{{ user_name }}"

        - name: copy secret key
          ansible.builtin.copy:
            remote_src: false
            src: "{{ secret_key }}"
            dest: "{{ ssh_key_file }}"
            mode: "600"
          become_user: "{{ user_name }}"

        - name: setup authorized_keys
          ansible.posix.authorized_key:
            user: "{{ user_name }}"
            key: "{{ lookup('ansible.builtin.file', public_key) }}"

        - name: setup ssh config
          ansible.builtin.blockinfile:
            path: "{{ ssh_config_file }}"
            create: true
            block: |
              <<ssh_config_content>>
          become_user: "{{ user_name }}"

        - name: create known_hosts
          ansible.builtin.file:
            path: "{{ known_hosts_file }}"
            state: "touch"
            mode: "600"
          become_user: "{{ user_name }}"

        - name: setup known_hosts
          ansible.builtin.shell: |
            cat <<EOF |
            <<known_hosts_content>>
            EOF
            while read -r ip; do
              pubkey_line=$(ssh-keyscan -t rsa "${ip}")
              if ! cat "{{ known_hosts_file }}" | grep -q "${pubkey_line}"; then
                echo "${pubkey_line}" >> "{{ known_hosts_file }}"
              fi
            done
          become_user: "{{ user_name }}"
EOF

sed 's#<<user_name>>#'"${USER_NAME}"'#'                             |
sed 's#<<key_path>>#'"${KEY_PATH}"'#'                               |

awk '
/<<ssh_config_content>>/ {
  cmd = \
    "jq -c \".[]\" \"'"${HOST_LEDGER_FILE}"'\" | " \
    "while read -r line; " \
    "do " \
      "name=$(echo \"${line}\" | jq -r \".name\"); " \
      "ip=$(echo \"${line}\" | jq -r \".ip\"); " \
      "echo \"${name} ${ip}\"; " \
    "done"

  key_base = "'"${KEY_PATH##*/}"'"

  while ((cmd | getline) > 0) {
    name = $1
    ip = $2

    printf "              Host %s %s\n", name, ip
    printf "                Hostname %s\n", ip
    printf "                Identityfile ~/.ssh/%s\n", key_base
  }

  next
}
{ print }'                                                          |

awk '
/<<known_hosts_content>>/ {
  cmd = "jq -r \".[].ip\" \"'"${HOST_LEDGER_FILE}"'\""

  while ((cmd | getline) > 0) {
    ip = $1

    printf "            %s\n", ip
  }

  next
}
{ print }'                                                          |

cat >"${PLAYBOOK_FILE}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK_FILE}"
else
  ANSIBLE_SHELL_ALLOW_WORLD_READABLE_TEMP=1 ANSIBLE_PIPELINING=1    \
  ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"
fi
