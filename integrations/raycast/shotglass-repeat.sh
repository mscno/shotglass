#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Shotglass Repeat Area
# @raycast.mode silent
# @raycast.packageName Shotglass
# @raycast.icon 📸
# @raycast.description Capture the previous area immediately.

set -euo pipefail
open -b no.paraply.shotglass 'shotglass://repeat'
