#!/usr/bin/env bash

# Settings
ROS_DISTRO="melodic"
PACKAGE_FILE=$(realpath "$1")
ROS_BUILD="ros_build"
ROS_BUILT="ros_built"

ROS_OUT_LIST="$(realpath "$2")"
ROS_OUT_DIR=$(dirname "$ROS_OUT_LIST")
ROS_CP_DIR="$(realpath "$3")"

BENCHBOT_MSGS_HASH_DEFAULT='master'
BENCHBOT_MSGS_LOCATION='src/benchbot_msgs'

echo "Loading packages from: $PACKAGE_FILE"
echo "Building in: $ROS_OUT_DIR"
echo "Saving files list: $ROS_OUT_LIST"
echo "Coping files to: $ROS_CP_DIR"

# Pull the list of packages
packages=$(cat "$PACKAGE_FILE" | tr "\n" " ")
echo "Manually pulling headers & building libraries from the following ROS packages:"
echo "$packages"

# Ensure we have pip dependencies
pip install trollius catkin_tools

# Install into our temporary dumping ground...
set -e
pushd "$ROS_OUT_DIR"
rm -rf "$ROS_BUILD"
mkdir -v "$ROS_BUILD"
pushd "$ROS_BUILD"

proxychains4 -q rosinstall_generator \
    --rosdistro "$ROS_DISTRO" \
    --deps \
    --flat \
    $packages > ws.rosinstall
echo "[INFO] >>>>>> ws.rosinstall contents >>>>>>"
cat ws.rosinstall
echo "[INFO] >>>>>> ws.rosinstall ends >>>>>>"
proxychains4 -q wstool init -j8 src ws.rosinstall

if [ -z "$BENCHBOT_MSGS_HASH" ]; then
  echo "No 'benchbot_msgs' HASH provided, reverting to default ('$BENCHBOT_MSGS_HASH_DEFAULT')"
  BENCHBOT_MSGS_HASH="$BENCHBOT_MSGS_HASH_DEFAULT"
fi
echo "Using 'benchbot_msgs' commitish: $BENCHBOT_MSGS_HASH"
proxychains4 -q git clone https://github.com/qcr/benchbot_msgs.git "$BENCHBOT_MSGS_LOCATION"
pushd "$BENCHBOT_MSGS_LOCATION"
proxychains4 -q git checkout "$BENCHBOT_MSGS_HASH"
popd

catkin config \
    --install \
    --source-space src \
    --build-space build \
    --devel-space devel \
    --log-space log \
    --install-space install \
    --isolate-devel \
    --no-extend

catkin build

# Put everything into our completed build directory
popd
rm -rf "$ROS_BUILT"
mkdir -v  "$ROS_BUILT"
pushd "$ROS_BUILT"

cp -r ../"$ROS_BUILD"/install/lib .
cp -r ../"$ROS_BUILD"/install/include .

# Dump the built package list
cp "$PACKAGE_FILE" "$ROS_OUT_LIST"

# Clean up & copy files to output location
# TODO would love to remove... but Bazel really doesn't like dynamically
# generated file lists
popd
rm -rf "$ROS_CP_DIR/lib" "$ROS_CP_DIR/include"
cp -r "$ROS_BUILT"/* "$ROS_CP_DIR"
rm -rf "$ROS_BUILD" "$ROS_BUILT"
