.PHONY: exploded-image images check-control
exploded-image images: check-control
check-control:
	$(if $(findstring --jobserver,$(MAKEFLAGS)),$(error use make JOBS=N instead of -jN))
	test "$(JOBS)" = "$$NIX_BUILD_CORES"
exploded-image:
	mkdir -p build/$(CONF)/jdk/{bin,lib,include,jmods,modules/jdk.jpackage}
	mkdir -p build/$(CONF)/support/{modules_libs,modules_cmds}/java.base
	$(CC) -DCONTROL=1 control.c -Wl,-rpath,$(CURDIR)/unused -o build/$(CONF)/support/modules_cmds/java.base/java
	$(CC) -DCONTROL=1 -shared -fPIC control.c -Wl,-rpath,$(CURDIR)/unused -o build/$(CONF)/support/modules_libs/java.base/libresource.so
	cp build/$(CONF)/support/modules_cmds/java.base/java build/$(CONF)/jdk/bin/java
	cp build/$(CONF)/support/modules_libs/java.base/libresource.so build/$(CONF)/jdk/lib/resource
	cp build/$(CONF)/support/modules_cmds/java.base/java build/$(CONF)/jdk/modules/jdk.jpackage/embedded-resource
	printf selected > build/$(CONF)/jdk/include/header
images:
	"$(JDK_CONTROL_PYTHON)" -B "$(JDK_CONTROL_VERIFY)" build/$(CONF)/jdk/lib/resource "$$(cat cups-selected)/lib"
	"$(JDK_CONTROL_PYTHON)" -B "$(JDK_CONTROL_VERIFY)" build/$(CONF)/jdk/bin/java "$$(cat cups-selected)/lib"
	"$(JDK_CONTROL_PYTHON)" -B "$(JDK_CONTROL_VERIFY)" build/$(CONF)/jdk/modules/jdk.jpackage/embedded-resource "$$(cat cups-selected)/lib"
	"$(JDK_CONTROL_PYTHON)" -B "$(JDK_CONTROL_VERIFY)" build/$(CONF)/support/modules_libs/java.base/libresource.so "$$(cat cups-selected)/lib"
	"$(JDK_CONTROL_PYTHON)" -B "$(JDK_CONTROL_VERIFY)" build/$(CONF)/support/modules_cmds/java.base/java "$$(cat cups-selected)/lib"
	test ! build/$(CONF)/support/modules_libs/java.base/libresource.so -ef build/$(CONF)/jdk/lib/resource
	test ! build/$(CONF)/support/modules_cmds/java.base/java -ef build/$(CONF)/jdk/bin/java
	mkdir -p build/$(CONF)/selected-image
	cp -a build/$(CONF)/jdk/. build/$(CONF)/selected-image/
	cp build/$(CONF)/support/modules_libs/java.base/libresource.so build/$(CONF)/selected-image/jmods/embedded-library
	cp build/$(CONF)/support/modules_cmds/java.base/java build/$(CONF)/selected-image/jmods/embedded-command
	cp build/$(CONF)/jdk/modules/jdk.jpackage/embedded-resource build/$(CONF)/selected-image/jmods/embedded-resource
	cp compiler-selected boot-selected conf-selected build/$(CONF)/selected-image/
