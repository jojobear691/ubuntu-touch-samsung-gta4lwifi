#!/bin/sh
set +e

for i in $(seq 1 30); do
    lxc-info -n android 2>/dev/null | grep -q RUNNING && break
    sleep 1
done

cp /userdata/ut-scripts/ut_scheduling_policy_stub /userdata/android-data/local/tmp/ut_scheduling_policy_stub 2>/dev/null || exit 0
chmod 0755 /userdata/android-data/local/tmp/ut_scheduling_policy_stub 2>/dev/null || exit 0

timeout 5 lxc-attach -n android -- /system/bin/sh -c 'service list | grep -q "scheduling_policy:"' >/dev/null 2>&1 && exit 0

timeout 5 lxc-attach -n android -- /system/bin/sh -c '/data/local/tmp/ut_scheduling_policy_stub >/dev/kmsg 2>&1 &' >/dev/null 2>&1 || true

exit 0
