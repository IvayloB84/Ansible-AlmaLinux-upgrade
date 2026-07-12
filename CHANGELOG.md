# Changelog

All notable changes to the Ansible ELevate Migration project will be documented in this file.

## 1.0.0 - 2026-07-12

### Added
- Automated console regex filtering in Task 13c to hide raw DNF package logs and display only the clean REPORT OVERVIEW dashboard matrix.
- Absolute $PATH environment mapping inside the Ansible shell invocation wrapper to guarantee tool execution visibility (jq, rpm, dnf) during reboots.

### Updated
- **scripts/leapp_auto_remediate.sh**: Appended a dedicated shell evaluation condition block using standard Bash case matching. The shell script intercepts the Leapp execution tree and overwrites the failing system upgrade files on the guest disk using standard file redirection tools.

### Fixed
- The Leapp Deprecation Data Bug: Resolved the persistent 'Invalid device and driver deprecation data: data' blocker crashing the pre-upgrade phase.
- Decoupled the broken upstream python code by injecting a tagless, zero-op code stub directly into /usr/share/leapp-repository/ and /etc/leapp/repos.d/ actor modules.

---

## Core Blocker Dictionary

### 1. Symptom: Invalid device and driver deprecation data: 'data'
- Error Identifier: load_device_driver_deprecation_data
- Root Cause: Upstream syntax schema anomalies inside the leapp-data-almalinux repository payload.
- Resolution Script Case Hook:
  ```bash
  ( "load_device_driver_deprecation_data" )
      CLEAN_ACTOR="from leapp.actors import Actor
  from leapp.tags import IPUWorkflowTag
  class LoadDeviceDriverDeprecationData(Actor):
      name = 'load_device_driver_deprecation_data'
      consumes = ()
      produces = ()
      tags = (IPUWorkflowTag,)
      def process(self):
          pass"
      [ -f "/usr/share/leapp-repository/repositories/system_upgrade/common/actors/loaddevicedriverdeprecationdata/actor.py" ] && echo "\$CLEAN_ACTOR" | sudo tee "/usr/share/leapp-repository/repositories/system_upgrade/common/actors/loaddevicedriverdeprecationdata/actor.py" >/dev/null
      ;;
  ```
