#!/usr/bin/env bash
# Shared helpers for the PAN-OS XML API automation scripts. Source this, don't run
# it directly.
#
# Credentials travel as environment variables, never as literal values in argv or
# written to disk:
#   - PANOS_API_PASSWORD must be exported before calling panos_keygen.
#   - PANOS_API_KEY must be exported before calling anything else here (capture
#     panos_keygen's output into it: `export PANOS_API_KEY=$(panos_keygen ...)`).
# Both get fed to curl via `printf '%s' "$VAR" | curl ... --data-urlencode "x@-"`.
# printf is a bash builtin, not a separate process, so the value never shows up in
# `ps aux` output the way `curl --data-urlencode "x=$VAR"` or `printf ... | other`
# (an external printf) would. `@-` makes curl read that field's value from stdin
# instead of a file, so it never touches disk either.

set -euo pipefail

# panos_keygen <mgmt_ip> <username> -> prints the API key to stdout
# Reads the password from $PANOS_API_PASSWORD.
panos_keygen() {
  local mgmt_ip="$1" username="$2"
  local response
  response=$(printf '%s' "$PANOS_API_PASSWORD" | curl -sk -X POST "https://${mgmt_ip}/api/" \
    --data-urlencode "type=keygen" \
    --data-urlencode "user=${username}" \
    --data-urlencode "password@-")
  echo "$response" | grep -o '<key>[^<]*</key>' | sed -E 's#<key>(.*)</key>#\1#'
}

# panos_api_get <mgmt_ip> <xpath>
# Reads the API key from $PANOS_API_KEY.
panos_api_get() {
  local mgmt_ip="$1" xpath="$2"
  printf '%s' "$PANOS_API_KEY" | curl -sk -X POST "https://${mgmt_ip}/api/" \
    --data-urlencode "type=config" \
    --data-urlencode "action=get" \
    --data-urlencode "xpath=${xpath}" \
    --data-urlencode "key@-"
}

# panos_api_set <mgmt_ip> <xpath> <element_file>
# Reads the API key from $PANOS_API_KEY. element_file holds XML config, not a
# secret, so it's still just a plain temp file.
panos_api_set() {
  local mgmt_ip="$1" xpath="$2" element_file="$3"
  printf '%s' "$PANOS_API_KEY" | curl -sk -X POST "https://${mgmt_ip}/api/" \
    --data-urlencode "type=config" \
    --data-urlencode "action=set" \
    --data-urlencode "xpath=${xpath}" \
    --data-urlencode "element@${element_file}" \
    --data-urlencode "key@-"
}

# panos_api_delete <mgmt_ip> <xpath>
# Reads the API key from $PANOS_API_KEY.
panos_api_delete() {
  local mgmt_ip="$1" xpath="$2"
  printf '%s' "$PANOS_API_KEY" | curl -sk -X POST "https://${mgmt_ip}/api/" \
    --data-urlencode "type=config" \
    --data-urlencode "action=delete" \
    --data-urlencode "xpath=${xpath}" \
    --data-urlencode "key@-"
}

# panos_op <mgmt_ip> <cmd_xml_file> -> raw op-command response
# Reads the API key from $PANOS_API_KEY. cmd_file holds an op-command, not a
# secret, so it's still just a plain temp file.
panos_op() {
  local mgmt_ip="$1" cmd_file="$2"
  printf '%s' "$PANOS_API_KEY" | curl -sk -X POST "https://${mgmt_ip}/api/" \
    --data-urlencode "type=op" \
    --data-urlencode "cmd@${cmd_file}" \
    --data-urlencode "key@-"
}

# panos_wait_for_job <mgmt_ip> <job_id> [max_attempts] [interval_seconds]
# Prints the final job XML to stdout once status is FIN. Exits non-zero on timeout.
panos_wait_for_job() {
  local mgmt_ip="$1" job_id="$2"
  local max_attempts="${3:-60}" interval="${4:-10}"
  local cmd_file
  cmd_file=$(mktemp)
  printf '<show><jobs><id>%s</id></jobs></show>' "$job_id" >"$cmd_file"

  local i result status
  for ((i = 1; i <= max_attempts; i++)); do
    result=$(panos_op "$mgmt_ip" "$cmd_file")
    status=$(echo "$result" | grep -o '<status>[^<]*</status>' | head -1)
    if [[ "$status" == "<status>FIN</status>" ]]; then
      rm -f "$cmd_file"
      echo "$result"
      return 0
    fi
    sleep "$interval"
  done

  rm -f "$cmd_file"
  echo "Timed out waiting for job $job_id to finish" >&2
  return 1
}

# wait_for_panos_mgmt <mgmt_ip> [max_attempts] [interval_seconds]
# Polls the mgmt HTTPS endpoint until it responds at all (PAN-OS first boot can take
# 10-20+ minutes even after the Azure VM itself shows as "running"). No credentials
# needed - just checks the endpoint is up.
wait_for_panos_mgmt() {
  local mgmt_ip="$1"
  local max_attempts="${2:-90}" interval="${3:-10}"
  local i code

  for ((i = 1; i <= max_attempts; i++)); do
    code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 "https://${mgmt_ip}/api/" || true)
    if [[ "$code" != "000" && -n "$code" ]]; then
      echo "PAN-OS mgmt API reachable at https://${mgmt_ip}/api/ (http $code) after $((i * interval))s" >&2
      return 0
    fi
    sleep "$interval"
  done

  echo "Timed out waiting for PAN-OS mgmt API at https://${mgmt_ip}" >&2
  return 1
}

# panos_commit <mgmt_ip> [description]
# Reads the API key from $PANOS_API_KEY. Issues a commit and waits for it to
# finish. Prints the final job XML.
panos_commit() {
  local mgmt_ip="$1" description="${2:-Automated commit}"
  local cmd_file response job_id
  cmd_file=$(mktemp)
  printf '<commit><description>%s</description></commit>' "$description" >"$cmd_file"

  response=$(panos_op "$mgmt_ip" "$cmd_file")
  rm -f "$cmd_file"

  if echo "$response" | grep -q "no changes to commit"; then
    echo "$response"
    return 0
  fi

  job_id=$(echo "$response" | grep -o '<job>[0-9]*</job>' | sed -E 's#<job>([0-9]*)</job>#\1#')
  if [[ -z "$job_id" ]]; then
    echo "Commit did not return a job id: $response" >&2
    return 1
  fi
  panos_wait_for_job "$mgmt_ip" "$job_id" 30 10
}

# ensure_latest_content_installed <mgmt_ip> <content_tag>
# Reads the API key from $PANOS_API_KEY. content_tag is the XML element name
# under <request>, e.g. "content" (Apps and Threats) or
# "global-protect-clientless-vpn". Skips download/install if a version is already
# marked current, so re-running this is cheap.
ensure_latest_content_installed() {
  local mgmt_ip="$1" content_tag="$2"
  local cmd_file check_result response job_id

  cmd_file=$(mktemp)
  printf '<request><%s><upgrade><check></check></upgrade></%s></request>' "$content_tag" "$content_tag" >"$cmd_file"
  check_result=$(panos_op "$mgmt_ip" "$cmd_file")
  rm -f "$cmd_file"

  if echo "$check_result" | grep -q '<current>yes</current>'; then
    echo "${content_tag}: already current, skipping download/install" >&2
    return 0
  fi

  echo "${content_tag}: downloading latest..." >&2
  cmd_file=$(mktemp)
  printf '<request><%s><upgrade><download><latest></latest></download></upgrade></%s></request>' "$content_tag" "$content_tag" >"$cmd_file"
  response=$(panos_op "$mgmt_ip" "$cmd_file")
  rm -f "$cmd_file"
  job_id=$(echo "$response" | grep -o '<job>[0-9]*</job>' | sed -E 's#<job>([0-9]*)</job>#\1#')
  if [[ -z "$job_id" ]]; then
    echo "${content_tag} download did not return a job id: $response" >&2
    return 1
  fi
  panos_wait_for_job "$mgmt_ip" "$job_id" 60 10 >/dev/null

  echo "${content_tag}: installing latest..." >&2
  cmd_file=$(mktemp)
  printf '<request><%s><upgrade><install><version>latest</version></install></upgrade></%s></request>' "$content_tag" "$content_tag" >"$cmd_file"
  response=$(panos_op "$mgmt_ip" "$cmd_file")
  rm -f "$cmd_file"
  job_id=$(echo "$response" | grep -o '<job>[0-9]*</job>' | sed -E 's#<job>([0-9]*)</job>#\1#')
  if [[ -z "$job_id" ]]; then
    echo "${content_tag} install did not return a job id: $response" >&2
    return 1
  fi
  panos_wait_for_job "$mgmt_ip" "$job_id" 60 10 >/dev/null

  echo "${content_tag}: installed" >&2
}

# panos_reboot_and_wait <mgmt_ip>
# Reads the API key from $PANOS_API_KEY. The GlobalProtect Clientless VPN feature
# was observed to need a full reboot (not just a commit) before it actually started
# serving the portal/login page, even after the license, content, and config were
# all in place.
panos_reboot_and_wait() {
  local mgmt_ip="$1"
  local cmd_file
  cmd_file=$(mktemp)
  printf '<request><restart><system></system></restart></request>' >"$cmd_file"

  echo "Rebooting firewall at ${mgmt_ip}..." >&2
  panos_op "$mgmt_ip" "$cmd_file" >&2 || true
  rm -f "$cmd_file"

  # Give it a head start before polling - the mgmt API stays briefly reachable
  # while the reboot is still being initiated.
  sleep 30
  wait_for_panos_mgmt "$mgmt_ip" 90 10
}
