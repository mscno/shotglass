#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Shotglass Draw New Area
# @raycast.mode silent
# @raycast.packageName Shotglass
# @raycast.icon 📸
# @raycast.description Draw anywhere and capture on release.

set -euo pipefail
open -b no.paraply.shotglass 'shotglass://draw'
