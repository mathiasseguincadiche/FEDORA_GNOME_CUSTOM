#!/usr/bin/env bash
set -Eeuo pipefail
baseline_suspend_resume_precheck() { [[ -r /sys/power/mem_sleep ]]; }
baseline_suspend_resume_plan() { echo 'Inventory suspend capability only. Suspend/resume quality is certified after the corrective APPLY and reboot, never used to block installation of the fixes.'; }
baseline_suspend_resume_apply() { log_info BASELINE "mem_sleep=$(cat /sys/power/mem_sleep)"; }
baseline_suspend_resume_postcheck() { return 0; }
