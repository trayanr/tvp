.PHONY: exploded-image images
exploded-image:
	mkdir -p build/$(CONF)/jdk/{bin,lib,include,jmods}
	$(CC) -DCONTROL=1 control.c -Wl,-rpath,$(CURDIR)/unused -o build/$(CONF)/jdk/bin/java
	cp build/$(CONF)/jdk/bin/java build/$(CONF)/jdk/lib/resource
	printf selected > build/$(CONF)/jdk/include/header
images:
	"$(JDK_CONTROL_PYTHON)" -B "$(JDK_CONTROL_VERIFY)" build/$(CONF)/jdk/lib/resource "$$(cat cups-selected)/lib"
	mkdir -p build/$(CONF)/selected-image
	cp -a build/$(CONF)/jdk/. build/$(CONF)/selected-image/
	cp build/$(CONF)/jdk/lib/resource build/$(CONF)/selected-image/jmods/embedded-resource
	cp compiler-selected boot-selected conf-selected build/$(CONF)/selected-image/
