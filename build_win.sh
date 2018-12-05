#!/bin/bash

PROGNAME=$(basename $0)
VERSION="${PROGNAME} v1.4 for 328pb"
echo
echo ${VERSION}
echo

DIR_ARDUINO="C:\PROGRA~2\Arduino"
DIR_USER=${USERPROFILE}\\Documents\\Arduino
DIR_USER2=${USERPROFILE}\\AppData\\Local\\Arduino15\\packages
DIR_CURRENT=${PWD}
DIR_ARDUINO_BIN=${DIR_ARDUINO}\\hardware\\tools\\avr\\bin

DIR_HARDWARE1=${DIR_ARDUINO}\\hardware
DIR_HARDWARE2=${DIR_USER}\\hardware
DIR_HARDWARE3=${DIR_USER2}

DIR_TOOLS1=${DIR_ARDUINO}\\tools-builder
DIR_TOOLS2=${DIR_ARDUINO}\\hardware\\tools\\avr
DIR_TOOLS3=${DIR_USER2}

DIR_BUILTIN_LIB=${DIR_ARDUINO}\\libraries
DIR_LIB=${DIR_USER}\\libraries

DIR_INO_ROOT=examples
DIR_BUILD=build
DIR_EX_LIB=externals
DIR_OWN_LIB=VivicoreSerial

DIR_SKETCH=sketch
FW_HEX_SUFFIX="ino.with_bootloader.hex"
BUILD_OPTION_FILE="build.options.json"
BUILD_LOG_NAME="build.log"
BOARD_328P_NAME="arduino:avr:vivi:cpu=8MHzatmega328"
BOARD_328PB_NAME="pololu-a-star:avr:a-star328PB:version=8mhz"
DEFAULT_MICRO=328pb
MICRO_OPTION="328p or 328pb"

HARDWARE="-hardware "${DIR_HARDWARE1}

if [ -e "${DIR_HARDWARE2}" ]; then
    HARDWARE=${HARDWARE}" -hardware "${DIR_HARDWARE2}
fi

if [ -e "${DIR_HARDWARE3}" ]; then
    HARDWARE=${HARDWARE}" -hardware "${DIR_HARDWARE3}
fi

TOOLS="-tools "${DIR_TOOLS1}

if [ -e "${DIR_TOOLS2}" ]; then
    TOOLS=${TOOLS}" -tools "${DIR_TOOLS2}
fi

if [ -e "${DIR_TOOLS3}" ]; then
    TOOLS=${TOOLS}" -tools "${DIR_TOOLS3}
fi

export PATH="${DIR_ARDUINO_BIN}:${DIR_ARDUINO}:$PATH"

#echo DIR_ARDUINO=${DIR_ARDUINO}
#echo HARDWARE=${HARDWARE}
#echo TOOLS=${TOOLS}
#echo DIR_BUILTIN_LIB=${DIR_BUILTIN_LIB}
#echo DIR_LIB=${DIR_LIB}

BASEDIR=$(cd $(dirname $0); pwd)
#echo ${BASEDIR}

function Usage() {
  echo 
  echo "Usage: ${PROGNAME} [Options]"
  echo 
  echo "Option: One of the options must be required"
  echo "  -h, --help              Help"
  echo "      --version           Show version"
  echo "  -m, --mcu <mcu_name>    Specify the target MCU ${MICRO_OPTION}"
  echo "  -c, --clean             Clean"
  echo "  -a, --all               Build all fw"
  echo "  -r, --rebuild           Clean and Rebuild"
  echo "  -f, --fw <fw_name>      Build a specific fw"
  echo
  exit 1
}

PARAM=()
for opt in "$@"; do
    case "${opt}" in
    '-h' | '--help' )
      Usage
      ;;
    '--version' )
      echo ${VERSION}
      exit 1
      ;;
    '-a' | '--all' )
      # Build all
      flg_build_all=1
      shift
      ;;
    '-c' | '--clean' )
      # Clean
      flg_clean=1
      shift
      ;;
    '-r' | '--rebuild' )
      # Rebuild
      flg_clean=1
      flg_build_all=1
      shift
      ;;
    '-m' | '--mcu' )
      # mcu must need an arg
      if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
        echo "${PROGNAME}: $1 option requires an argument" 1>&2
        echo "Provide ${MICRO_OPTION}" 1>&2
        exit 1
      fi
      MCU_ARG=("$2")
      shift 2
      ;;
    '-f' | '--fw' )
      # firmware must need an arg
      if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
        echo "${PROGNAME}: $1 option requires an argument" 1>&2
        exit 1
      fi
      FW_ARG=("$2")
      shift 2
      ;;
    '--' | '-' )
      shift
      PARAM+=( "$@" )
      break
      ;;
    -* )
      echo "${PROGNAME}: $1 illegal option" 1>&2
      Usage
      ;;
    * )
      if [[ -n "$1" ]] && [[ ! "$1" =~ ^-+ ]]; then
          PARAM+=( "$1" ); shift
      fi
      ;;
    esac
done

# Arg without option
PARAM1="${PARAM}"; PARAM=("${PARAM[@]:1}")
#echo "PARAM1=${PARAM1}"
if [ -z "${FW_ARG}" ] && [ -z "${PARAM1}" ] && [ -z "${flg_clean}" ] && [ -z "${flg_build_all}" ]; then
  Usage
elif [ ! -n "${FW_ARG}" ]; then
  # argument without -f|--fw option is treated as FW_ARG
  FW_ARG="${PARAM1}"
fi

# Verify ${MCU_ARG} and define ${BOARD_NAME}
if [ ! -n "${MCU_ARG}" ]; then
  MCU_TYPE=${DEFAULT_MICRO}
else
  MCU_TYPE=${MCU_ARG}
fi
MCU_UPPER=`echo ${MCU_TYPE} | tr '[a-z]' '[A-Z]'`
if [ "${MCU_UPPER}" = "328P" ]; then
  BOARD_NAME=${BOARD_328P_NAME}
elif [ "${MCU_UPPER}" = "328PB" ]; then
  BOARD_NAME=${BOARD_328PB_NAME}
else
  echo "Cannot recognize -m/--mcu argument ${MCU_ARG}" 1>&2
  echo "Provide ${MICRO_OPTION}" 1>&2
  exit 1
fi

# Verify ${FW_ARG} and create ${REL_INO_FILE}
if [ -n "${FW_ARG}" ]; then
  if [ -e "${FW_ARG}" ]; then
    if [ -f "${FW_ARG}" ] && [ ${FW_ARG##*.} = ino ]; then
      # If ${FW_ARG} is ino file full path
      INO_FILE_NAME=${FW_ARG##*/}
      INO_DIR_NAME=${INO_FILE_NAME%.*}
      REL_INO_FILE="${FW_ARG}"
      #echo "${FW_ARG} = ino file full path: ${REL_INO_FILE}"
    else
      # If ${FW_ARG} is ino directory full path
      INO_DIR_NAME=`basename ${FW_ARG}`
      REL_INO_FILE="${FW_ARG}/${INO_DIR_NAME}.ino"
      #echo "${FW_ARG} = ino directory path: ${REL_INO_FILE}"
    fi
  elif [ -d "${DIR_INO_ROOT}/${FW_ARG}" ]; then
    # If ${FW_ARG} is ino directory name
    INO_DIR_NAME=${FW_ARG}
    REL_INO_FILE="${DIR_INO_ROOT}/${INO_DIR_NAME}/${INO_DIR_NAME}.ino"
    #echo "${FW_ARG} = ino file name: ${REL_INO_FILE}"
  else
    echo "Cannot recognize -f/--fw argument ${FW_ARG}" 1>&2
    exit 1
  fi
  #echo "INO_DIR_NAME=${INO_DIR_NAME}"
fi

# In case of illegal option
if [[ -n "${PARAM[@]}" ]]; then
  echo "${PARAM[@]}"
  echo "Cannot recognize arguments" 1>&2
  Usage
fi

echo "----------------------------"
echo "MCU       = ${MCU_UPPER}"
echo "Clean     = ${flg_clean}"
echo "Build_all = ${flg_build_all}"
echo "FW        = ${INO_DIR_NAME}"
echo "----------------------------"

function Clean() {
  if [ $# -eq 0 ]; then
    echo "Clean function needs an argument"
    exit 1
  fi
  ino_name=("$1")
  DIR_INO_PATH=${DIR_INO_ROOT}/${ino_name}
  DIR_REL_BUILD_PATH=${DIR_INO_PATH}/${DIR_BUILD}

  echo "Clean ${DIR_INO_PATH}"
  if [ -e "${DIR_REL_BUILD_PATH}" ]; then
    rm -r "${DIR_REL_BUILD_PATH}"
    #rm "${DIR_INO_PATH}/${BUILD_LOG_NAME}"
  fi
}

function CompileFirmware() {
  if [ $# -eq 0 ]; then
    echo "ComplileFirmware function needs an argument"
    exit 1
  fi
  ino_name=("$1")

  DIR_INO_PATH=${DIR_INO_ROOT}/${ino_name}
  if [ ! -e ${DIR_INO_PATH}/${ino_name}.ino ]; then
    echo "Skip ${ino_name} due to no ino file"
    return
  fi
  DIR_REL_BUILD_PATH=${DIR_INO_PATH}/${DIR_BUILD}
  if [ ! -e "${DIR_REL_BUILD_PATH}" ]; then
    mkdir -p "${DIR_REL_BUILD_PATH}"
  elif [ -e "${DIR_REL_BUILD_PATH}/${DIR_SKETCH}" ]; then
    rm -r "${DIR_REL_BUILD_PATH}/${DIR_SKETCH}"
  fi

  #echo DIR_INO_PATH=${DIR_INO_PATH}
  #echo DIR_REL_BUILD_PATH=${DIR_REL_BUILD_PATH}

  DIR_ABS_BUILD_PATH=$(cd $DIR_REL_BUILD_PATH && pwd)
  #echo DIR_ABS_BUILD_PATH=${DIR_ABS_BUILD_PATH}

  # Backup existing fw binary
  if [ -e "${DIR_INO_ROOT}/${ino_name}/${DIR_BUILD}/${ino_name}.${FW_HEX_SUFFIX}" ]; then
    mv "${DIR_INO_ROOT}/${ino_name}/${DIR_BUILD}/${ino_name}.${FW_HEX_SUFFIX}" "${DIR_INO_ROOT}/${ino_name}/${DIR_BUILD}/${ino_name}.${FW_HEX_SUFFIX}.bak"
  fi
  # Remove json to avoid build error when recompiling
  if [ -e "${DIR_INO_ROOT}/${ino_name}/${DIR_BUILD}/${BUILD_OPTION_FILE}" ]; then
    rm "${DIR_INO_ROOT}/${ino_name}/${DIR_BUILD}/${BUILD_OPTION_FILE}"
  fi

  # Compile
  echo "Building ${DIR_INO_PATH}/${ino_name}.ino for ATmega${MCU_UPPER}"

  #echo arduino-builder -dump-prefs ${HARDWARE} ${TOOLS} -built-in-libraries "${DIR_BUILTIN_LIB}" -libraries "${DIR_LIB}" -fqbn="${BOARD_NAME}" -build-path "${DIR_ABS_BUILD_PATH}" -verbose ${DIR_INO_PATH}/${ino_name}.ino
  arduino-builder -dump-prefs ${HARDWARE} ${TOOLS} -built-in-libraries "${DIR_BUILTIN_LIB}" -libraries "${DIR_LIB}" -fqbn="${BOARD_NAME}" -build-path "${DIR_ABS_BUILD_PATH}" -verbose ${DIR_INO_PATH}/${ino_name}.ino > "${DIR_ABS_BUILD_PATH}/${BUILD_LOG_NAME}" 2>&1

  #echo arduino-builder -compile ${HARDWARE} ${TOOLS} -built-in-libraries "${DIR_BUILTIN_LIB}" -libraries "${DIR_LIB}" -fqbn="${BOARD_NAME}" -build-path "${DIR_ABS_BUILD_PATH}" -verbose ${DIR_INO_PATH}/${ino_name}.ino
  arduino-builder -compile ${HARDWARE} ${TOOLS} -built-in-libraries "${DIR_BUILTIN_LIB}" -libraries "${DIR_LIB}" -fqbn="${BOARD_NAME}" -build-path "${DIR_ABS_BUILD_PATH}" -verbose ${DIR_INO_PATH}/${ino_name}.ino >> "${DIR_ABS_BUILD_PATH}/${BUILD_LOG_NAME}" 2>&1
}

function VerifyBuildResult() {
  if [ $# -eq 0 ]; then
    echo "VerifyBuildResult function needs an argument"
    exit 1
  fi
  ino_name=("$1")
  if [ ! -e "${DIR_INO_ROOT}/${ino_name}/${ino_name}.ino" ]; then
    # Skip verification in case of no ino file
    return
  fi
  if [ ! -e "${DIR_INO_ROOT}/${ino_name}/${DIR_BUILD}/${ino_name}.${FW_HEX_SUFFIX}" ]; then
    echo "${ino_name} build failed! See ${DIR_INO_ROOT}/${ino_name}/${DIR_BUILD}/${BUILD_LOG_NAME}"
  else
    echo "Successfully ${ino_name}.${FW_HEX_SUFFIX} generated for ATmega${MCU_UPPER}."
  fi
}

if [ -n "${flg_clean}" ]; then
  # Clean user libraries
  echo "Clean ${DIR_LIB}/${DIR_OWN_LIB}"
  rm -r "${DIR_LIB}/${DIR_OWN_LIB}"
fi

if [ -n "${flg_build_all}" ] || [ -n "${REL_INO_FILE}" ]; then
  # Copy root *.h *.cpp to ${DIR_LIB}
  #for lib_file in `\find . -maxdepth 1 -type f -name *.h | sed 's!^.*/!!'`; do
  for lib_file in `ls -1 *.cpp *.h`; do
    if [ ! -e "${DIR_LIB}/${DIR_OWN_LIB}" ]; then
      mkdir -p "${DIR_LIB}/${DIR_OWN_LIB}"
    fi
    cp "${lib_file}" "${DIR_LIB}/${DIR_OWN_LIB}"
    echo "Copied ${lib_file} to ${DIR_LIB}/${DIR_OWN_LIB}"
  done

  # Copy libraries directory to ${DIR_LIB}
  cp -R ${DIR_EX_LIB}/* "${DIR_LIB}/"
  echo "Copied ${DIR_EX_LIB}/* to ${DIR_LIB}/"
fi

if [ -n "${FW_ARG}" ]; then
  if [ ! -e "${REL_INO_FILE}" ]; then
    echo "Cannot find ${REL_INO_FILE}"
    exit 1
  fi
fi

if [ ! -n "${FW_ARG}" ]; then
  LS_CMD="ls -1 ${DIR_INO_ROOT}"
  echo "Try to look into directories under ${DIR_INO_ROOT}"
else
  LS_CMD="echo ${INO_DIR_NAME}"
fi
#echo "LS_CMD=${LS_CMD}"

# Clean and Compile
for ino_dir in `${LS_CMD}`; do
  if [ ! -d "${DIR_INO_ROOT}/$ino_dir" ]; then
    continue
  fi
  if [ -n "${flg_clean}" ] || [ -n "${MCU_ARG}" ]; then
    # If user specifies MCU_ARG with -m/--mcu option, target micro might be changed.
    # Since arduino-builder reuses the cached core.a, core.a should be regenerated in above case.
    Clean "$ino_dir"
  fi
  if [ -n "${FW_ARG}" ] || [ -n "${flg_build_all}" ]; then
    CompileFirmware "$ino_dir"
  fi
done

# Verify compile results
if [ -n "${FW_ARG}" ] || [ -n "${flg_build_all}" ]; then
  echo
  echo "============================================================"
  for ino_dir in `${LS_CMD}`; do
    if [ ! -d "${DIR_INO_ROOT}/$ino_dir" ]; then
      continue
    fi
    VerifyBuildResult ${ino_dir}
  done
fi

echo
echo "Done"

exit 0

