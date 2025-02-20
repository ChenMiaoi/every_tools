#!/usr/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

error_exit() {
    echo "Error on line $1"
    exit 1
}

trap 'error_exit $LINENO' ERR

# Install necessary packages
# sudo apt-get update
sudo apt-get -y install autoconf autogen pkg-config byacc patch automake libtool make file \
libncurses-dev gettext unzip bzip2 zip util-linux wget git python3 mysql-server openssl libssl-dev \
openjdk-17-jdk openjdk-17-jre

# Create a symbolic link for python
sudo ln -sf /usr/bin/python3 /usr/bin/python

# Start and enable MySQL service
sudo systemctl start mysql
sudo systemctl enable mysql

# Clone the Doris repository
if [ ! -d "doris" ]; then
    git clone git@github.com:ChenMiaoi/doris.git
    if [ ! -d "doris" ]; then
        echo "Failed to clone Doris repository"
        exit 1
    fi
else
    echo "Doris repository already exists, skipping clone."
fi

# Create and navigate to the environment directory
mkdir -p env
pushd env

# Download and execute the ldb_toolchain_gen script
if [ ! -d "/home/nya/env/ldb_toolchain/bin" ]; then
    wget https://github.com/amosbird/ldb_toolchain_gen/releases/download/v0.19/ldb_toolchain_gen.sh
    bash ldb_toolchain_gen.sh /home/nya/env/ldb_toolchain
    if [ ! -d "/home/nya/env/ldb_toolchain/bin" ]; then
        echo "Failed to create ldb_toolchain directory"
        exit 1
    fi
else
    echo "ldb_toolchain directory already exists, skipping download and execution."
fi

# Download and extract Apache Maven
if [ ! -x "apache-maven-3.6.3/bin/mvn" ]; then
    wget https://doris-thirdparty-repo.bj.bcebos.com/thirdparty/apache-maven-3.6.3-bin.tar.gz
    tar zxvf apache-maven-3.6.3-bin.tar.gz
    if [ ! -f "apache-maven-3.6.3/bin/mvn" ]; then
        echo "Failed to extract Apache Maven"
        exit 1
    fi
else
    echo "Apache Maven already exists, skipping download and extraction."
fi

# Download and extract Node.js
if [ ! -x "node-v12.13.0-linux-x64/bin/node" ]; then
    wget https://doris-thirdparty-repo.bj.bcebos.com/thirdparty/node-v12.13.0-linux-x64.tar.gz
    tar zxvf node-v12.13.0-linux-x64.tar.gz
    if [ ! -f "node-v12.13.0-linux-x64/bin/node" ]; then
        echo "Failed to extract Node.js"
        exit 1
    fi
else
    echo "Node.js already exists, skipping download and extraction."
fi

# Download and extract Doris third-party prebuilt binaries
if [ ! -d "../doris/thirdparty/installed" ]; then
    wget https://github.com/apache/doris-thirdparty/releases/download/automation/doris-thirdparty-prebuilt-linux-x86_64.tar.xz
    tar Jxvf doris-thirdparty-prebuilt-linux-x86_64.tar.xz
    if [ ! -d "installed" ]; then
        echo "Failed to extract Doris third-party prebuilt binaries"
        exit 1
    fi
    # Move the installed third-party binaries to the Doris directory
    mv installed ../doris/thirdparty/
else
    echo "Doris third-party prebuilt binaries already exist, skipping download and extraction."
fi

# Create a custom environment setup script
cat > custom_env.sh <<EOF
#!/usr/bin/bash

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=\$JAVA_HOME/bin:\$PATH
export PATH=$(pwd)/apache-maven-3.6.3/bin:\$PATH
export PATH=$(pwd)/node-v12.13.0-linux-x64/bin:\$PATH
export PATH=$(pwd)/ldb_toolchain/bin:\$PATH
EOF

cp custom_env.sh ../doris/

popd

# Print the contents of custom_env.sh
cat env/custom_env.sh

# Prompt user to continue
read -p "Press y to continue: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

# Prompt user to select build type
echo "Select build type:"
echo "1) Debug"
echo "2) Release (default)"
echo "3) ASAN"
read -p "Enter your choice [1-3]: " -r
case $REPLY in
    1) TYPE=Debug ;;
    3) TYPE=ASAN ;;
    *) TYPE=Release ;;
esac

pushd doris

BUILD_TYPE=$TYPE bash build.sh -j$(nproc)

popd
