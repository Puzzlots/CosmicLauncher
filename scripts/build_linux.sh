#flutter build linux

mkdir packing
cp -r build/linux/x64/release/bundle packing

./scripts/linuxdeploy-x86_64.appimage --appdir AppDir --executable ./packing/polaris_launcher --library ./lib