[[ -z "${ARC_PATH}" || ! -d "${ARC_PATH}/include" ]] && ARC_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" 2>/dev/null && pwd)"

. ${ARC_PATH}/include/functions.sh

###############################################################################
# Upgrade Loader
function upgradeLoader () {
  (
    local ARCNIC="$(readConfigKey "arc.nic" "${USER_CONFIG_FILE}")"
    TAG=""
    if [ -z "${1}" ]; then
      # Check for new Version
      idx=0
      while [ ${idx} -le 5 ]; do # Loop 5 times, if successful, break
        if [ "${ARCNIC}" == "auto" ]; then
          TAG="$(curl -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        else
          TAG="$(curl  --interface ${ARCNIC} -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        fi
        if [ -n "${TAG}" ]; then
          echo "New Version: ${TAG}"
          break
        fi
        sleep 3
        idx=$((${idx} + 1))
      done
      if [ -z "${TAG}" ]; then
        echo "Error checking new Version!"
        sleep 5
        updateFailed
      fi
    else
      TAG="${1}"
    fi
    # Download update file
    echo "Downloading ${TAG}"
    if [ "${ARCNIC}" == "auto" ]; then
      curl -#kL "https://github.com/AuxXxilium/arc/releases/download/${TAG}/arc-${TAG}.img.zip" -o "${TMP_PATH}/arc-${TAG}.img.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
    else
      curl --interface ${ARCNIC} -#kL "https://github.com/AuxXxilium/arc/releases/download/${TAG}/arc-${TAG}.img.zip" -o "${TMP_PATH}/arc-${TAG}.img.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
    fi
    if [ -f "${TMP_PATH}/arc-${TAG}.img.zip" ]; then
      echo "Downloading Upgradefile successful!"
    else
      echo "Error downloading Upgradefile!"
      sleep 5
      return 1
    fi
    unzip -oq "${TMP_PATH}/arc-${TAG}.img.zip" -d "${TMP_PATH}"
    rm -f "${TMP_PATH}/arc-${TAG}.img.zip" >/dev/null
    echo "Installing new Loader Image..."
    # Process complete update
    umount "${PART1_PATH}" "${PART2_PATH}" "${PART3_PATH}"
    dd if="${TMP_PATH}/arc.img" of=$(blkid | grep 'LABEL="ARC3"' | cut -d3 -f1) bs=1M conv=fsync
    # Ask for Boot
    rm -f "${TMP_PATH}/arc.img" >/dev/null
    echo "Upgrade done! -> Rebooting..."
    sleep 2
  ) 2>&1 | dialog --backtitle "$(backtitle)" --title "Upgrade Loader" \
    --progressbox "Upgrading Loader..." 20 70
}

###############################################################################
# Update Loader
function updateLoader() {
  (
    local ARCNIC="$(readConfigKey "arc.nic" "${USER_CONFIG_FILE}")"
    TAG=""
    if [ -z "${1}" ]; then
      # Check for new Version
      idx=0
      while [ ${idx} -le 5 ]; do # Loop 5 times, if successful, break
        if [ "${ARCNIC}" == "auto" ]; then
          TAG="$(curl -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        else
          TAG="$(curl  --interface ${ARCNIC} -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        fi
        if [ -n "${TAG}" ]; then
          echo "New Version: ${TAG}"
          break
        fi
        sleep 3
        idx=$((${idx} + 1))
      done
      if [ -z "${TAG}" ]; then
        echo "Error checking new Version!"
        sleep 5
        updateFailed
      fi
    else
      TAG="${1}"
    fi
    # Download update file
    echo "Downloading ${TAG}"
    if [ "${ARCNIC}" == "auto" ]; then
      curl -#kL "https://github.com/AuxXxilium/arc/releases/download/${TAG}/update.zip" -o "${TMP_PATH}/update.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl -skL "https://github.com/AuxXxilium/arc/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    else
      curl --interface ${ARCNIC} -#kL "https://github.com/AuxXxilium/arc/releases/download/${TAG}/update.zip" -o "${TMP_PATH}/update.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl --interface ${ARCNIC} -skL "https://github.com/AuxXxilium/arc/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    fi
    if [ "$(sha256sum "${TMP_PATH}/update.zip" | awk '{print $1}')" = "$(cat ${TMP_PATH}/checksum.sha256 | awk '{print $1}')" ]; then
      echo "Download successful!"
      unzip -oq "${TMP_PATH}/update.zip" -d "${TMP_PATH}"
      echo "Installing new Loader Image..."
      cp -f "${TMP_PATH}/grub.cfg" "${USER_GRUB_CONFIG}"
      cp -f "${TMP_PATH}/bzImage-arc" "${ARC_BZIMAGE_FILE}"
      cp -f "${TMP_PATH}/initrd-arc" "${ARC_RAMDISK_FILE}"
      rm -f "${TMP_PATH}/grub.cfg" "${TMP_PATH}/bzImage-arc" "${TMP_PATH}/initrd-arc"
      rm -f "${TMP_PATH}/update.zip"
    else
      echo "Error getting new Version!"
      sleep 5
      updateFailed
    fi
    [ -f "${TMP_PATH}/update.zip" ] && rm -f "${TMP_PATH}/update.zip"
    echo "Update done!"
    sleep 2
  ) 2>&1 | dialog --backtitle "$(backtitle)" --title "Update Loader" \
    --progressbox "Updating Loader..." 20 70
  return 0
}

###############################################################################
# Update Addons
function updateAddons() {
  (
    local ARCNIC="$(readConfigKey "arc.nic" "${USER_CONFIG_FILE}")"
    TAG=""
    if [ -z "${1}" ]; then
      # Check for new Version
      idx=0
      while [ ${idx} -le 5 ]; do # Loop 5 times, if successful, break
        if [ "${ARCNIC}" == "auto" ]; then
          TAG="$(curl -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc-addons/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        else
          TAG="$(curl --interface ${ARCNIC} -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc-addons/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        fi
        if [ -n "${TAG}" ]; then
          echo "New Version: ${TAG}"
          break
        fi
        sleep 3
        idx=$((${idx} + 1))
      done
      if [ -z "${TAG}" ]; then
        echo "Error checking new Version!"
        sleep 5
        updateFailed
      fi
    else
      TAG="${1}"
    fi
    # Download update file
    echo "Downloading ${TAG}"
    if [ "${ARCNIC}" == "auto" ]; then
      curl -#kL "https://github.com/AuxXxilium/arc-addons/releases/download/${TAG}/addons.zip" -o "${TMP_PATH}/addons.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl -skL "https://github.com/AuxXxilium/arc-addons/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    else
      curl --interface ${ARCNIC} -#kL "https://github.com/AuxXxilium/arc-addons/releases/download/${TAG}/addons.zip" -o "${TMP_PATH}/addons.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl --interface ${ARCNIC} -skL "https://github.com/AuxXxilium/arc-addons/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    fi
    if [ "$(sha256sum "${TMP_PATH}/addons.zip" | awk '{print $1}')" = "$(cat ${TMP_PATH}/checksum.sha256 | awk '{print $1}')" ]; then
      echo "Download successful!"
      rm -rf "${ADDONS_PATH}"
      mkdir -p "${ADDONS_PATH}"
      echo "Installing new Addons..."
      unzip -oq "${TMP_PATH}/addons.zip" -d "${ADDONS_PATH}"
      rm -f "${TMP_PATH}/addons.zip"
      for F in $(ls ${ADDONS_PATH}/*.addon 2>/dev/null); do
        ADDON=$(basename "${F}" | sed 's|.addon||')
        rm -rf "${ADDONS_PATH}/${ADDON}"
        mkdir -p "${ADDONS_PATH}/${ADDON}"
        echo "Installing ${F} to ${ADDONS_PATH}/${ADDON}"
        tar -xaf "${F}" -C "${ADDONS_PATH}/${ADDON}"
        rm -f "${F}"
      done
    else
      echo "Error extracting new Version!"
      sleep 5
      updateFailed
    fi
    echo "Update done!"
    sleep 2
  ) 2>&1 | dialog --backtitle "$(backtitle)" --title "Update Addons" \
    --progressbox "Updating Addons..." 20 70
  return 0
}

###############################################################################
# Update Patches
function updatePatches() {
  (
    local ARCNIC="$(readConfigKey "arc.nic" "${USER_CONFIG_FILE}")"
    TAG=""
    if [ -z "${1}" ]; then
      # Check for new Version
      idx=0
      while [ ${idx} -le 5 ]; do # Loop 5 times, if successful, break
        if [ "${ARCNIC}" == "auto" ]; then
          TAG="$(curl -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc-patches/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        else
          TAG="$(curl --interface ${ARCNIC} -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc-patches/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        fi
        if [ -n "${TAG}" ]; then
          echo "New Version: ${TAG}"
          break
        fi
        sleep 3
        idx=$((${idx} + 1))
      done
      if [ -z "${TAG}" ]; then
        echo "Error checking new Version!"
        sleep 5
        updateFailed
      fi
    else
      TAG="${1}"
    fi
    # Download update file
    echo "Downloading ${TAG}"
    if [ "${ARCNIC}" == "auto" ]; then
      curl -#kL "https://github.com/AuxXxilium/arc-patches/releases/download/${TAG}/patches.zip" -o "${TMP_PATH}/patches.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl -skL "https://github.com/AuxXxilium/arc-patches/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    else
      curl --interface ${ARCNIC} -#kL "https://github.com/AuxXxilium/arc-patches/releases/download/${TAG}/patches.zip" -o "${TMP_PATH}/patches.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl --interface ${ARCNIC} -skL "https://github.com/AuxXxilium/arc-patches/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    fi
    if [ "$(sha256sum "${TMP_PATH}/patches.zip" | awk '{print $1}')" = "$(cat ${TMP_PATH}/checksum.sha256 | awk '{print $1}')" ]; then
      echo "Download successful!"
      rm -rf "${PATCH_PATH}"
      mkdir -p "${PATCH_PATH}"
      echo "Installing new Patches..."
      unzip -oq "${TMP_PATH}/patches.zip" -d "${PATCH_PATH}"
      rm -f "${TMP_PATH}/patches.zip"
    else
      echo "Error extracting new Version!"
      sleep 5
      updateFailed
    fi
    echo "Update done!"
    sleep 2
  ) 2>&1 | dialog --backtitle "$(backtitle)" --title "Update Patches" \
    --progressbox "Updating Patches..." 20 70
  return 0
}

###############################################################################
# Update Modules
function updateModules() {
  (
    local ARCNIC="$(readConfigKey "arc.nic" "${USER_CONFIG_FILE}")"
    TAG=""
    if [ -z "${1}" ]; then
      # Check for new Version
      idx=0
      while [ ${idx} -le 5 ]; do # Loop 5 times, if successful, break
        if [ "${ARCNIC}" == "auto" ]; then
          TAG="$(curl -m 10 -skL "https://api.github.com/repos/AuxXxilium/arc-modules/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        else
          TAG="$(curl --interface ${ARCNIC} -m 10 -skL "https://api.github.com/repos/AuxXxilium/arc-modules/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        fi
        if [ -n "${TAG}" ]; then
          echo "New Version: ${TAG}"
          break
        fi
        sleep 3
        idx=$((${idx} + 1))
      done
      if [ -z "${TAG}" ]; then
        echo "Error checking new Version!"
        sleep 5
        updateFailed
      fi
    else
      TAG="${1}"
    fi
    # Download update file
    echo "Downloading ${TAG}"
    if [ "${ARCNIC}" == "auto" ]; then
      curl -#kL "https://github.com/AuxXxilium/arc-modules/releases/download/${TAG}/modules.zip" -o "${TMP_PATH}/modules.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl -skL "https://github.com/AuxXxilium/arc-modules/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    else
      curl --interface ${ARCNIC} -#kL "https://github.com/AuxXxilium/arc-modules/releases/download/${TAG}/modules.zip" -o "${TMP_PATH}/modules.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl --interface ${ARCNIC} -skL "https://github.com/AuxXxilium/arc-modules/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    fi
    if [ "$(sha256sum "${TMP_PATH}/modules.zip" | awk '{print $1}')" = "$(cat ${TMP_PATH}/checksum.sha256 | awk '{print $1}')" ]; then
      echo "Download successful!"
      rm -rf "${MODULES_PATH}"
      mkdir -p "${MODULES_PATH}"
      echo "Installing new Modules..."
      unzip -oq "${TMP_PATH}/modules.zip" -d "${MODULES_PATH}"
      rm -f "${TMP_PATH}/modules.zip"
      # Rebuild modules if model/build is selected
      local PRODUCTVER="$(readConfigKey "productver" "${USER_CONFIG_FILE}")"
      if [ -n "${PRODUCTVER}" ]; then
        local PLATFORM="$(readConfigKey "platform" "${USER_CONFIG_FILE}")"
        local KVER="$(readConfigKey "platforms.${PLATFORM}.productvers.\"${PRODUCTVER}\".kver" "${P_FILE}")"
        # Modify KVER for Epyc7002
        if [ "${PLATFORM}" = "epyc7002" ]; then
          KVERP="${PRODUCTVER}-${KVER}"
        else
          KVERP="${KVER}"
        fi
      fi
      if [ -n "${PLATFORM}" ] && [ -n "${KVERP}" ]; then
        writeConfigKey "modules" "{}" "${USER_CONFIG_FILE}"
        echo "Rebuilding Modules..."
        while read -r ID DESC; do
          writeConfigKey "modules.${ID}" "" "${USER_CONFIG_FILE}"
        done < <(getAllModules "${PLATFORM}" "${KVERP}")
      fi
    else
      echo "Error extracting new Version!"
      sleep 5
      updateFailed
    fi
    echo "Update done!"
    sleep 2
  ) 2>&1 | dialog --backtitle "$(backtitle)" --title "Update Modules" \
    --progressbox "Updating Modules..." 20 70
  return 0
}

###############################################################################
# Update Configs
function updateConfigs() {
  (
    local ARCNIC="$(readConfigKey "arc.nic" "${USER_CONFIG_FILE}")"
    TAG=""
    if [ -z "${1}" ]; then
      # Check for new Version
      idx=0
      while [ ${idx} -le 5 ]; do # Loop 5 times, if successful, break
        if [ "${ARCNIC}" == "auto" ]; then
          TAG="$(curl -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc-configs/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        else
          TAG="$(curl --interface ${ARCNIC} -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc-configs/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        fi
        if [ -n "${TAG}" ]; then
          echo "New Version: ${TAG}"
          break
        fi
        sleep 3
        idx=$((${idx} + 1))
      done
      if [ -z "${TAG}" ]; then
        echo "Error checking new Version!"
        sleep 5
        updateFailed
      fi
    else
      TAG="${1}"
    fi
    # Download update file
    echo "Downloading ${TAG}"
    if [ "${ARCNIC}" == "auto" ]; then
      curl -#kL "https://github.com/AuxXxilium/arc-configs/releases/download/${TAG}/configs.zip" -o "${TMP_PATH}/configs.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl -skL "https://github.com/AuxXxilium/arc-configs/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    else
      curl --interface ${ARCNIC} -#kL "https://github.com/AuxXxilium/arc-configs/releases/download/${TAG}/configs.zip" -o "${TMP_PATH}/configs.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
      curl --interface ${ARCNIC} -skL "https://github.com/AuxXxilium/arc-configs/releases/download/${TAG}/checksum.sha256" -o "${TMP_PATH}/checksum.sha256"
    fi
    if [ "$(sha256sum "${TMP_PATH}/configs.zip" | awk '{print $1}')" = "$(cat ${TMP_PATH}/checksum.sha256 | awk '{print $1}')" ]; then
      echo "Download successful!"
      rm -rf "${MODEL_CONFIG_PATH}"
      mkdir -p "${MODEL_CONFIG_PATH}"
      echo "Installing new Configs..."
      unzip -oq "${TMP_PATH}/configs.zip" -d "${MODEL_CONFIG_PATH}"
      rm -f "${TMP_PATH}/configs.zip"
    else
      echo "Error extracting new Version!"
      sleep 5
      updateFailed
    fi
    echo "Update done!"
    sleep 2
  ) 2>&1 | dialog --backtitle "$(backtitle)" --title "Update Configs" \
    --progressbox "Updating Configs..." 20 70
  return 0
}

###############################################################################
# Update LKMs
function updateLKMs() {
  (
    local ARCNIC="$(readConfigKey "arc.nic" "${USER_CONFIG_FILE}")"
    TAG=""
    if [ -z "${1}" ]; then
      # Check for new Version
      idx=0
      while [ ${idx} -le 5 ]; do # Loop 5 times, if successful, break
        if [ "${ARCNIC}" == "auto" ]; then
          TAG="$(curl -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc-lkm/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        else
          TAG="$(curl --interface ${ARCNIC} -m 5 -skL "https://api.github.com/repos/AuxXxilium/arc-lkm/releases" | jq -r ".[].tag_name" | sort -rV | head -1)"
        fi
        if [ -n "${TAG}" ]; then
          echo "New Version: ${TAG}"
          break
        fi
        sleep 3
        idx=$((${idx} + 1))
      done
      if [ -z "${TAG}" ]; then
        echo "Error checking new Version!"
        sleep 5
        updateFailed
      fi
    else
      TAG="${1}"
    fi
    # Download update file
    echo "Downloading ${TAG}"
    if [ "${ARCNIC}" == "auto" ]; then
      curl -#kL "https://github.com/AuxXxilium/arc-lkm/releases/download/${TAG}/rp-lkms.zip" -o "${TMP_PATH}/rp-lkms.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
    else
      curl --interface ${ARCNIC} -#kL "https://github.com/AuxXxilium/arc-lkm/releases/download/${TAG}/rp-lkms.zip" -o "${TMP_PATH}/rp-lkms.zip" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Download: $progress%" && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
      done
    fi
    if [ -f "${TMP_PATH}/rp-lkms.zip" ]; then
      echo "Download successful!"
      rm -rf "${LKMS_PATH}"
      mkdir -p "${LKMS_PATH}"
      echo "Installing new LKMs..."
      unzip -oq "${TMP_PATH}/rp-lkms.zip" -d "${LKMS_PATH}"
      rm -f "${TMP_PATH}/rp-lkms.zip"
    else
      echo "Error extracting new Version!"
      sleep 5
      updateFailed
    fi
    echo "Update done!"
    sleep 2
  ) 2>&1 | dialog --backtitle "$(backtitle)" --title "Update LKMs" \
    --progressbox "Updating LKMs..." 20 70
  return 0
}

###############################################################################
# Update Failed
function updateFailed() {
  local AUTOMATED="$(readConfigKey "arc.automated" "${USER_CONFIG_FILE}")"
  if [ "${AUTOMATED}" = "true" ]; then
    dialog --backtitle "$(backtitle)" --title "Update Failed" \
      --infobox "Update failed!" 0 0
    sleep 5
    exec reboot
  else
    dialog --backtitle "$(backtitle)" --title "Update Failed" \
      --msgbox "Update failed!" 0 0
    exit 1
  fi
}