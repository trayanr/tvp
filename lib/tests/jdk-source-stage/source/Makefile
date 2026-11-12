.PHONY: exploded-image images check-control
exploded-image images: check-control
check-control:
	$(if $(findstring --jobserver,$(MAKEFLAGS)),$(error use make JOBS=N instead of -jN))
	test "$(JOBS)" = "$$NIX_BUILD_CORES"
exploded-image:
	mkdir -p build/$(CONF)/jdk/{bin,lib,include,jmods,modules/jdk.jpackage/jdk/jpackage/internal/resources,modules/java.base}
	mkdir -p build/$(CONF)/support/{modules_libs,modules_cmds}/java.base
	$(CC) -DCONTROL=1 control.c -Wl,-rpath,$(CURDIR)/unused -o build/$(CONF)/support/modules_cmds/java.base/java
	$(CC) -DCONTROL=1 -shared -fPIC control.c -Wl,-rpath,$(CURDIR)/unused -o build/$(CONF)/support/modules_libs/java.base/libresource.so
	cp build/$(CONF)/support/modules_cmds/java.base/java build/$(CONF)/jdk/bin/java
	cp build/$(CONF)/support/modules_libs/java.base/libresource.so build/$(CONF)/jdk/lib/resource
	cp build/$(CONF)/support/modules_libs/java.base/libresource.so build/$(CONF)/jdk/lib/libresource.so
	cp build/$(CONF)/support/modules_cmds/java.base/java build/$(CONF)/jdk/modules/jdk.jpackage/jdk/jpackage/internal/resources/jpackageapplauncher
	cp build/$(CONF)/support/modules_libs/java.base/libresource.so build/$(CONF)/jdk/modules/jdk.jpackage/jdk/jpackage/internal/resources/libjpackageapplauncheraux.so
	printf compiled > build/$(CONF)/jdk/modules/java.base/module-info.class
	printf release > build/$(CONF)/jdk/release
	printf source > build/$(CONF)/support/src.zip
	printf selected > build/$(CONF)/jdk/include/header
images:
	cp compiler-selected boot-selected conf-selected build/$(CONF)/jdk/
	mkdir -p build/$(CONF)/selected-image
	cp -a build/$(CONF)/jdk/. build/$(CONF)/selected-image/
	cp compiler-selected boot-selected conf-selected build/$(CONF)/selected-image/
