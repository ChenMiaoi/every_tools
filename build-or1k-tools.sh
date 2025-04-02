#!/bin/bash

# Global variables
# OPENRISC_PREFIX="/opt/toolchain/or1k-elf"
OPENRISC_PREFIX="$HOME/env/toolchain/or1k-elf"
OPENRISC_TOOL_PREFIX="$HOME/env/toolchain/or1k-tools"
WORK_DIR="$HOME/work/openrisc"
BUILD_BINUTILS=false
BUILD_GCC=false
BUILD_GDB=false
BUILD_QEMU=false
BUILD_LINUX=false
USE_GMP=false
USE_MPFR=false
USE_MPC=false
CLEAN_CACHE=false
CLEAN_TARGET="all"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print success messages
success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print info messages
info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

# Function to setup build dependencies (Ubuntu/Debian only)
setup_dependency() {
  info "Installing required build dependencies for Ubuntu/Debian"

  # Check if we're on a Debian-based system
  if ! command -v apt-get >/dev/null 2>&1; then
    error "This script currently only supports Ubuntu/Debian for dependency installation"
    error "Please install the following packages manually:"
    error "gcc, g++, make, cmake, autogen, automake, autoconf, zlib1g-dev, texinfo, build-essential, flex, bison, git, wget, xz-utils"
    return 1
  fi

  # Update package lists
  sudo apt-get update || {
    error "Failed to update package lists"
    return 1
  }

  # Install required packages
  sudo apt-get install -y \
    gcc \
    g++ \
    make \
    cmake \
    autogen \
    automake \
    autoconf \
    zlib1g-dev \
    texinfo \
    build-essential \
    flex \
    bison \
    git \
    wget \
    xz-utils ||
    {
      error "Failed to install dependencies"
      return 1
    }

  success "Build dependencies installed successfully"
  return 0
}

# Function to check and create work directory
setup_work_dir() {
  if [ ! -d "$WORK_DIR" ]; then
    info "Creating work directory at $WORK_DIR"
    mkdir -p "$WORK_DIR" || {
      error "Failed to create work directory"
      exit 1
    }
  fi
  cd "$WORK_DIR" || {
    error "Failed to change to work directory"
    exit 1
  }
}

# Function to set up prefix in PATH
setup_prefix() {
  local bashrc="$HOME/.bashrc"
  local path_line="export PATH=\$PATH:$OPENRISC_PREFIX/bin"

  if ! grep -q "$path_line" "$bashrc"; then
    info "Adding $OPENRISC_PREFIX/bin to PATH in $bashrc"
    echo "$path_line" >>"$bashrc" || {
      error "Failed to update $bashrc"
      exit 1
    }
    source "$bashrc"
  else
    source "$bashrc"
  fi
}

# setup_prefix() {
#   local profile_dir="/etc/profile.d"
#   local profile_file="${profile_dir}/or1k-toolchain.sh"

#   # Create the directory if it doesn't exist
#   if [ ! -d "$profile_dir" ]; then
#     info "Creating profile.d directory"
#     sudo mkdir -p "$profile_dir" || {
#       error "Failed to create profile.d directory"
#       return 1
#     }
#   fi

#   # Create or update the profile file
#   info "Setting up system-wide PATH in ${profile_file}"
#   echo "export PATH=\$PATH:${OPENRISC_PREFIX}/bin" | sudo tee "$profile_file" >/dev/null || {
#     error "Failed to create profile file"
#     return 1
#   }

#   # Set proper permissions
#   sudo chmod 644 "$profile_file" || {
#     error "Failed to set permissions on profile file"
#     return 1
#   }

#   # Load the new PATH in current session
#   if source "$profile_file"; then
#     # Also source for root if we're not already root
#     if [ "$(id -u)" -ne 0 ]; then
#       sudo -H bash -c "source '$profile_file'" || {
#         error "Failed to load new PATH configuration for root"
#         return 1
#       }
#     fi
#   else
#     error "Failed to load new PATH configuration"
#     return 1
#   fi

#   success "Toolchain PATH configured system-wide in ${profile_file}"
#   return 0
# }

# Function to clone repositories
clone_repos() {
  # Clone GCC if not exists
  if [ ! -d "gcc" ]; then
    info "Cloning GCC repository"
    git clone --depth 1 git://gcc.gnu.org/git/gcc.git gcc || {
      error "Failed to clone GCC"
      exit 1
    }
  fi

  # Clone binutils-gdb if not exists
  if [ ! -d "binutils-gdb" ]; then
    info "Cloning binutils-gdb repository"
    git clone --depth 1 git://sourceware.org/git/binutils-gdb.git binutils-gdb || {
      error "Failed to clone binutils-gdb"
      exit 1
    }
  fi

  # Clone newlib if not exists
  if [ ! -d "newlib" ]; then
    info "Cloning newlib repository"
    git clone --depth 1 git://sourceware.org/git/newlib-cygwin.git newlib || {
      error "Failed to clone newlib"
      exit 1
    }
  fi
}

# Function to check if library is already built
is_library_built() {
  local lib_name="$1"
  local lib_path="$OPENRISC_TOOL_PREFIX/$lib_name"

  # Check if installation directory exists and contains files
  [ -d "$lib_path" ] && [ -n "$(ls -A "$lib_path")" ] &&
    # Check if library files exist
    [ -f "$lib_path/lib/lib$lib_name.a" ] || [ -f "$lib_path/lib/lib$lib_name.so" ]
}

# Function to setup GMP (extraction only)
setup_gmp() {
  if [ ! -d "gmp-6.1.0" ]; then
    info "Downloading and extracting GMP"
    wget https://gmplib.org/download/gmp/gmp-6.1.0.tar.xz || {
      error "Failed to download GMP"
      exit 1
    }
    tar -xf gmp-6.1.0.tar.xz || {
      error "Failed to extract GMP"
      exit 1
    }
    rm gmp-6.1.0.tar.xz
  fi

  if [ ! -L "gcc/gmp" ]; then
    ln -s ../gmp-6.1.0 gcc/gmp || {
      error "Failed to create symlink for GMP"
      exit 1
    }
  fi
}

# Function to setup MPFR (extraction only)
setup_mpfr() {
  if [ ! -d "mpfr-3.1.6" ]; then
    info "Downloading and extracting MPFR"
    wget https://www.mpfr.org/mpfr-3.1.6/mpfr-3.1.6.tar.xz || {
      error "Failed to download MPFR"
      exit 1
    }
    tar -xf mpfr-3.1.6.tar.xz || {
      error "Failed to extract MPFR"
      exit 1
    }
    rm mpfr-3.1.6.tar.xz
  fi

  if [ ! -L "gcc/mpfr" ]; then
    ln -s ../mpfr-3.1.6 gcc/mpfr || {
      error "Failed to create symlink for MPFR"
      exit 1
    }
  fi
}

# Function to setup MPC (extraction only)
setup_mpc() {
  if [ ! -d "mpc-1.0.3" ]; then
    info "Downloading and extracting MPC"
    wget ftp://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz || {
      error "Failed to download MPC"
      exit 1
    }
    tar -xf mpc-1.0.3.tar.gz || {
      error "Failed to extract MPC"
      exit 1
    }
    rm mpc-1.0.3.tar.gz
  fi

  if [ ! -L "gcc/mpc" ]; then
    ln -s ../mpc-1.0.3 gcc/mpc || {
      error "Failed to create symlink for MPC"
      exit 1
    }
  fi
}

# Main build function for all extra libraries
build_extra() {
  # Build GMP if not already built
  if ! is_library_built "gmp"; then
    info "Building GMP..."
    pushd gmp-6.1.0 >/dev/null || {
      error "Failed to change to GMP build directory"
      return 1
    }

    ./configure --prefix="$OPENRISC_TOOL_PREFIX/gmp" || {
      error "Failed to configure GMP"
      return 1
    }

    make -j "$(nproc)" || {
      error "Failed to build GMP"
      return 1
    }

    make install || {
      error "Failed to install GMP"
      return 1
    }

    popd >/dev/null
    success "GMP built and installed successfully"
  else
    info "GMP already built, skipping..."
  fi

  # Build MPFR if not already built (depends on GMP)
  if ! is_library_built "mpfr"; then
    info "Building MPFR..."
    pushd mpfr-3.1.6 >/dev/null || {
      error "Failed to change to MPFR build directory"
      return 1
    }

    ./configure --prefix="$OPENRISC_TOOL_PREFIX/mpfr" \
      --with-gmp="$OPENRISC_TOOL_PREFIX/gmp" || {
      error "Failed to configure MPFR"
      return 1
    }

    make -j "$(nproc)" || {
      error "Failed to build MPFR"
      return 1
    }

    make install || {
      error "Failed to install MPFR"
      return 1
    }

    popd >/dev/null
    success "MPFR built and installed successfully"
  else
    info "MPFR already built, skipping..."
  fi

  # Build MPC if not already built (depends on MPFR and GMP)
  if ! is_library_built "mpc"; then
    info "Building MPC..."
    pushd mpc-1.0.3 >/dev/null || {
      error "Failed to change to MPC build directory"
      return 1
    }

    ./configure --prefix="$OPENRISC_TOOL_PREFIX/mpc" \
      --with-mpfr="$OPENRISC_TOOL_PREFIX/mpfr" \
      --with-gmp="$OPENRISC_TOOL_PREFIX/gmp" || {
      error "Failed to configure MPC"
      return 1
    }

    make -j "$(nproc)" || {
      error "Failed to build MPC"
      return 1
    }

    make install || {
      error "Failed to install MPC"
      return 1
    }

    popd >/dev/null
    success "MPC built and installed successfully"
  else
    info "MPC already built, skipping..."
  fi
}

# Function to build binutils
build_binutils() {
  info "Building binutils"
  mkdir -p binutils-gdb/build-binutils || {
    error "Failed to create build directory for binutils"
    exit 1
  }

  pushd binutils-gdb/build-binutils >/dev/null || {
    error "Failed to change to binutils build directory"
    exit 1
  }

  ../configure --target=or1k-elf --prefix="$OPENRISC_PREFIX" \
    --disable-itcl \
    --disable-tk \
    --disable-tcl \
    --disable-winsup \
    --disable-gdbtk \
    --disable-libgui \
    --disable-rda \
    --disable-sid \
    --disable-sim \
    --disable-gdb \
    --with-sysroot \
    --disable-newlib \
    --disable-libgloss \
    --with-system-zlib || {
    error "Failed to configure binutils"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build binutils"
    exit 1
  }

  make install || {
    error "Failed to install binutils"
    exit 1
  }

  popd >/dev/null
  success "Binutils built and installed successfully"
}

# Function to build GCC stage1
build_gcc_stage1() {
  info "Building GCC stage1"
  mkdir -p gcc/build-gcc-stage1 || {
    error "Failed to create build directory for GCC stage1"
    exit 1
  }

  pushd gcc/build-gcc-stage1 >/dev/null || {
    error "Failed to change to GCC stage1 build directory"
    exit 1
  }

  ../configure --target=or1k-elf \
    --prefix="$OPENRISC_PREFIX" \
    --enable-languages=c \
    --disable-shared \
    --disable-libssp || {
    error "Failed to configure GCC stage1"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build GCC stage1"
    exit 1
  }

  make install || {
    error "Failed to install GCC stage1"
    exit 1
  }

  popd >/dev/null
  success "GCC stage1 built and installed successfully"
}

# Function to build newlib
build_newlib() {
  info "Building newlib"
  mkdir -p newlib/build-newlib || {
    error "Failed to create build directory for newlib"
    exit 1
  }

  pushd newlib/build-newlib >/dev/null || {
    error "Failed to change to newlib build directory"
    exit 1
  }

  ../configure --target=or1k-elf --prefix="$OPENRISC_PREFIX" || {
    error "Failed to configure newlib"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build newlib"
    exit 1
  }

  make install || {
    error "Failed to install newlib"
    exit 1
  }

  popd >/dev/null
  success "Newlib built and installed successfully"
}

# Function to build GCC stage2
build_gcc_stage2() {
  info "Building GCC stage2"
  mkdir -p gcc/build-gcc-stage2 || {
    error "Failed to create build directory for GCC stage2"
    exit 1
  }

  pushd gcc/build-gcc-stage2 >/dev/null || {
    error "Failed to change to GCC stage2 build directory"
    exit 1
  }

  ../configure --target=or1k-elf \
    --prefix="$OPENRISC_PREFIX" \
    --enable-languages=c,c++ \
    --disable-shared \
    --disable-libssp \
    --with-newlib || {
    error "Failed to configure GCC stage2"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build GCC stage2"
    exit 1
  }

  make install || {
    error "Failed to install GCC stage2"
    exit 1
  }

  popd >/dev/null
  success "GCC stage2 built and installed successfully"
}

# Function to build GDB
build_gdb() {
  info "Building GDB"
  mkdir -p binutils-gdb/build-gdb || {
    error "Failed to create build directory for GDB"
    exit 1
  }

  build_extra

  pushd binutils-gdb/build-gdb >/dev/null || {
    error "Failed to change to GDB build directory"
    exit 1
  }

  ../configure --target=or1k-elf \
    --prefix="$OPENRISC_PREFIX" \
    --with-gmp="$OPENRISC_TOOL_PREFIX/gmp" \
    --with-mpfr="$OPENRISC_TOOL_PREFIX/mpfr" \
    --disable-itcl \
    --disable-tk \
    --disable-tcl \
    --disable-winsup \
    --disable-gdbtk \
    --disable-libgui \
    --disable-rda \
    --disable-sid \
    --with-sysroot \
    --disable-newlib \
    --disable-libgloss \
    --disable-gas \
    --disable-ld \
    --disable-binutils \
    --disable-gprof \
    --with-system-zlib || {
    error "Failed to configure GDB"
    exit 1
  }

  make -j "$(nproc)" || {
    error "Failed to build GDB"
    exit 1
  }

  make install || {
    error "Failed to install GDB"
    exit 1
  }

  popd >/dev/null
  success "GDB built and installed successfully"
}

# Add QEMU build function
build_qemu() {
  local qemu_version="9.2.3"
  local qemu_dir="qemu-${qemu_version}"
  local qemu_archive="${qemu_dir}.tar.xz"
  local qemu_url="https://download.qemu.org/${qemu_archive}"

  info "Building QEMU ${qemu_version}"

  # Download QEMU if not exists
  if [ ! -f "${WORK_DIR}/${qemu_archive}" ]; then
    info "Downloading QEMU"
    wget "${qemu_url}" || {
      error "Failed to download QEMU"
      return 1
    }
  fi

  # Extract QEMU
  if [ ! -d "${WORK_DIR}/${qemu_dir}" ]; then
    info "Extracting QEMU"
    tar -xJf "${WORK_DIR}/${qemu_archive}" || {
      error "Failed to extract QEMU"
      return 1
    }
  fi

  sudo apt-get install -y libglib2.0-dev pkgconf ninja-build python3-venv python3-pip python3-full || {
    error "Failed to install dependencies"
    return 1
  }

  # python3 -m pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple --upgrade pip || {
  #   error "cannot set pypi tsinghua mirror"
  #   return 1
  # }

  # python3 -m pip install --upgrade pip || {
  #   error "cannot upgrade pip"
  #   return 1
  # }

  # pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple || {
  #   error "cannot set pypi tsinghua mirror"
  #   return 1
  # }

  # Build QEMU
  pushd "${WORK_DIR}/${qemu_dir}" >/dev/null || {
    error "Failed to enter QEMU directory"
    return 1
  }

  info "Configuring QEMU"
  ./configure --prefix="$OPENRISC_TOOL_PREFIX/qemu" \
    --target-list=or1k-softmmu,or1k-linux-user || {
    error "QEMU configuration failed"
    popd >/dev/null
    return 1
  }

  info "Building QEMU"
  make -j$(nproc) || {
    error "QEMU build failed"
    popd >/dev/null
    return 1
  }

  info "Installing QEMU"
  make install || {
    error "QEMU installation failed"
    popd >/dev/null
    return 1
  }

  popd >/dev/null

  # Add QEMU to PATH in .bashrc
  local bashrc="$HOME/.bashrc"
  local qemu_path_line="export PATH=\$PATH:${OPENRISC_TOOL_PREFIX}/qemu/bin"

  if ! grep -q "${qemu_path_line}" "$bashrc"; then
    info "Adding QEMU to PATH in ${bashrc}"
    echo "${qemu_path_line}" >>"$bashrc" || {
      error "Failed to update ${bashrc}"
      return 1
    }
    # Source the updated .bashrc
    source "$bashrc"
  else
    source "$bashrc"
  fi

  success "QEMU ${qemu_version} built and installed successfully"
  return 0
}

# Add Linux kernel build function
build_linux() {
  info "Building Linux kernel for OpenRISC"

  # Clone Linux repository if not exists
  if [ ! -d "linux" ]; then
    info "Cloning Linux repository"
    git clone --depth 1 https://github.com/openrisc/linux.git linux || {
      error "Failed to clone Linux repository"
      return 1
    }
  fi

  pushd linux >/dev/null || {
    error "Failed to enter Linux directory"
    return 1
  }

  # Set up environment for cross-compilation
  export ARCH=openrisc
  export CROSS_COMPILE=or1k-elf-

  # Check if toolchain is in PATH
  if ! command -v ${CROSS_COMPILE}gcc >/dev/null 2>&1; then
    error "OpenRISC toolchain not found in PATH. Please build toolchain first or add to PATH."
    popd >/dev/null
    return 1
  fi

  info "Configuring Linux kernel"
  make defconfig || {
    error "Failed to configure Linux kernel"
    popd >/dev/null
    return 1
  }

  info "Building Linux kernel"
  make -j$(nproc) || {
    error "Failed to build Linux kernel"
    popd >/dev/null
    return 1
  }

  popd >/dev/null
  success "Linux kernel built successfully"
  return 0
}

clean_toolchain() {
  # Remove build directories
  local build_dirs=(
    "binutils-gdb/build-binutils"
    "binutils-gdb/build-gdb"
    "gcc/build-gcc-stage1"
    "gcc/build-gcc-stage2"
    "newlib/build-newlib"
  )

  for dir in "${build_dirs[@]}"; do
    if [ -d "$WORK_DIR/$dir" ]; then
      info "Make Clean $dir"
      make -C "${WORK_DIR:?}/$dir" distclean || {
        error "Failed to Make distclean $dir"
        return 1
      }

      info "Removing $dir"
      rm -rf "${WORK_DIR:?}/$dir" || {
        error "Failed to remove $dir"
        return 1
      }
    fi
  done

  if [ -d "$OPENRISC_PREFIX" ]; then
    info "Removing installed toolchain from $OPENRISC_PREFIX"

    # Safety check - verify this looks like a toolchain directory
    if [ -x "$OPENRISC_PREFIX/bin/or1k-elf-"* ] || [ -d "$OPENRISC_PREFIX/lib" ]; then
      sudo rm -rf "${OPENRISC_PREFIX:?}" || {
        error "Failed to remove installed toolchain"
        return 1
      }

      # Also remove the profile file if it exists
      # local profile_file="/etc/profile.d/or1k-toolchain.sh"
      # if [ -f "$profile_file" ]; then
      #   info "Removing profile file: $profile_file"
      #   sudo rm -f "$profile_file" || {
      #     error "Failed to remove profile file"
      #     return 1
      #   }
      # fi
    else
      warning "$OPENRISC_PREFIX doesn't appear to contain or1k toolchain - skipping removal"
    fi
  else
    info "No installed toolchain found at $OPENRISC_PREFIX"
  fi

  local bashrc="$HOME/.bashrc"
  local path_line="export PATH=\$PATH:$OPENRISC_PREFIX/bin"

  remove_path_entry "$bashrc" "$path_line"
}

clean_extra() {
  # Remove extracted source directories (but keep symlinks in gcc/)
  local source_dirs=(
    "gmp-6.1.0"
    "mpfr-3.1.6"
    "mpc-1.0.3"
  )

  local install_paths=(
    "$OPENRISC_TOOL_PREFIX/gmp"
    "$OPENRISC_TOOL_PREFIX/mpfr"
    "$OPENRISC_TOOL_PREFIX/mpc"
  )

  for dir in "${source_dirs[@]}"; do
    if [ -d "$WORK_DIR/$dir" ]; then
      info "Make Clean $dir"
      make -C "${WORK_DIR:?}/$dir" distclean || {
        error "Failed to Make distclean $dir"
        return 1
      }

      # info "Removing $dir"
      # rm -rf "${WORK_DIR:?}/$dir" || {
      #   error "Failed to remove $dir"
      #   return 1
      # }
    fi
  done

  for path in "${install_paths[@]}"; do
    if [ -d "$path" ]; then
      info "Removing installed files: $path"
      rm -rf "${path:?}" || {
        error "Failed to remove installed files at $path"
        return 1
      }
    fi
  done
}

clean_qemu() {
  local qemu_version="9.2.3"
  local qemu_files="qemu-${qemu_version}"
  local qemu_install_dir="${OPENRISC_TOOL_PREFIX}/qemu"

  if [ -d "${qemu_files}" ]; then
    info "Clean Qemu Build Cache"
    make -C "$WORK_DIR/$qemu_files" distclean || {
      error "Failed to clean Qemu Build Cache"
      return 1
    }
  fi

  if [ -d "${qemu_install_dir}" ]; then
    info "Removing installed QEMU from ${qemu_install_dir}"
    rm -rf "${qemu_install_dir}" || {
      error "Failed to remove QEMU installation"
      return 1
    }
  fi

  # Remove QEMU PATH from .bashrc
  local bashrc="$HOME/.bashrc"
  local qemu_path_line="export PATH=\$PATH:${qemu_install_dir}/bin"

  remove_path_entry "$bashrc" "$qemu_path_line"
}

clean_linux() {
  info "Clean Linux Build Cache"
  if [ -d "${WORK_DIR}/linux" ]; then
    make -C "${WORK_DIR}/linux" mrproper || {
      error "Failed to clean Linux Build Cache"
      return 1
    }
  fi
}

remove_path_entry() {
  local file="$1"
  local pattern="$2"

  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    info "Removing PATH entry from ${file}"
    sed -i "\|${pattern}|d" "$file" || {
      error "Failed to modify ${file}"
      return 1
    }

    # Also remove from current environment
    export PATH=$(echo "$PATH" | sed "s|:${pattern#*=}||")
  fi
}

clean_cache() {
  local target="${1:-all}" # Default to clean all if no target specified
  info "Starting clean operation for target: $target"

  case "$target" in
  qemu)
    clean_qemu || return $?
    ;;
  linux)
    clean_linux || return $?
    ;;
  toolchain)
    clean_toolchain || return $?
    ;;
  extra)
    clean_extra || return $?
    ;;
  all)
    clean_qemu || return $?
    clean_linux || return $?
    clean_extra || return $?
    clean_toolchain || return $?
    ;;
  *)
    error "Invalid clean target: $target. Valid targets are: binutils, gcc, newlib, qemu, linux, toolchain, all"
    return 1
    ;;
  esac

  success "Clean operation completed for target: $target"
  return 0
}

# Function to parse arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --prefix=*)
      OPENRISC_PREFIX="${1#*=}"
      shift
      ;;
    --use-gmp)
      USE_GMP=true
      shift
      ;;
    --use-mpfr)
      USE_MPFR=true
      shift
      ;;
    --use-mpc)
      USE_MPC=true
      shift
      ;;
    --use-extra)
      USE_GMP=true
      USE_MPFR=true
      USE_MPC=true
      shift
      ;;
    --build-binutils)
      BUILD_BINUTILS=true
      shift
      ;;
    --build-gcc)
      BUILD_GCC=true
      shift
      ;;
    --build-gdb)
      BUILD_GDB=true
      shift
      ;;
    --build-qemu)
      BUILD_QEMU=true
      shift
      ;;
    --build-linux)
      BUILD_LINUX=true
      shift
      ;;
    --clean=*)
      CLEAN_CACHE=true
      CLEAN_TARGET="${1#*=}"
      shift
      ;;
    --clean)
      CLEAN_CACHE=true
      CLEAN_TARGET="all" # Default to clean all
      shift
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
    esac
  done
}

# Main function
main() {
  parse_arguments "$@"

  if [ "$CLEAN_CACHE" = true ]; then
    clean_cache "$CLEAN_TARGET"
    exit $?
  fi

  if $BUILD_QEMU; then
    build_qemu
    exit $?
  fi

  if $BUILD_LINUX; then
    build_linux
    exit $?
  fi

  info "Starting OpenRISC toolchain build process"
  info "Toolchain prefix: $OPENRISC_PREFIX"

  setup_dependency
  setup_work_dir
  setup_prefix
  clone_repos

  # Setup extra libraries if needed
  if $USE_GMP; then setup_gmp; fi
  if $USE_MPFR; then setup_mpfr; fi
  if $USE_MPC; then setup_mpc; fi

  # Build components as requested
  if $BUILD_BINUTILS; then build_binutils; fi

  setup_prefix

  if $BUILD_GCC; then
    build_gcc_stage1
    build_newlib
    build_gcc_stage2
  fi

  if $BUILD_GDB; then build_gdb; fi

  success "OpenRISC toolchain build process completed successfully"
}

# Execute main function
main "$@"
