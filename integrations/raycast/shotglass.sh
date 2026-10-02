#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Shotglass
# @raycast.mode silent
# @raycast.packageName Shotglass
# @raycast.icon 📸
# @raycast.description Open the compact capture bar with the last mode selected.

set -euo pipefail
open -b no.paraply.shotglass 'shotglass://capture'
