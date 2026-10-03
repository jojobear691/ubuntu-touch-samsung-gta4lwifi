#!/bin/sh
set +e
mkdir -p /userdata/ut-apt/lists/partial /userdata/ut-apt/cache/archives/partial
mountpoint -q /var/lib/apt/lists || mount --bind /userdata/ut-apt/lists /var/lib/apt/lists
mountpoint -q /var/cache/apt || mount --bind /userdata/ut-apt/cache /var/cache/apt
mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial
chmod 755 /var/lib/apt/lists /var/lib/apt/lists/partial /var/cache/apt /var/cache/apt/archives /var/cache/apt/archives/partial
df -hT / /var/lib/apt/lists /var/cache/apt /userdata
