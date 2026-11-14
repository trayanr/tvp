# JDK 21.0.13 source boundary

A retains configure, exploded-image, images and raw installation, with no
runtime-aware ELF repair. Its Nix checkpoint retains the full exploded JDK
(compiled module classes, tools, release/jrt data), modules_libs/cmds/conf/include/
man/legal, src.zip, link_opt/classlist/JLI data, optional demo image, make scripts,
text generated specs and source module/legal metadata. It excludes native/Java
implementation source and test inputs. Exact checkpoint size is UNKNOWN until
later bounded compilation. The retained legacy/bootstrap procedures are unchanged.

F copies only the raw public image and epoch receipt, repairs its loaders and
RPATHs, strips native products, then mirrors the repaired bytes into exact matching
private module-native inputs. The original raw image must match each native input
before mapping. The compiled jpackage launcher and auxiliary library are staged
under the final root and receive the existing interpreter, selected-runtime RPATH
and strip operations. Their repaired bytes return to the private module class
tree before packaging; the temporary resource stage is removed. Native CreateJmods
runs all non-java.base modules first, then
java.base with native hash generation; Images.gmk jdk runs jlink and the existing
profile's image-only CDS, release, src.zip and jpackage packaging. Module version,
target, date, compression, classlist and JLI flags come from retained native specs.
No structured/signed payload rewriting, javac, native compiler, bootstrap or
compile-dependent optimization is dispatched. CC/CXX/JAVAC are explicitly false;
only the two native packaging makefiles are invoked, never Main.gmk/top-level
images. Native jmod/jlink/java come from the repaired public image. No shell
forwarder is installed. The selected configurationName/imageDirectory remain
explicit. Nine installed factory tests remain registered separately.

Field classification:

* A: src/version/patches/buildNumber, configurationName/imageDirectory, base,
  bootJdk, bash (native childproc fallback), fontconfig (native dlopen constant),
  all native/Java headers and linked libraries, libcups and X providers, configure
  options, generators, compiler environment and normal construction tools.
  Direct Bash/Fontconfig/library override/edit still invalidates A.
* F: runtime.libraries, runtime.dlopenDirectories (defaults through final.libcups),
  dynamicLinker, assemblyScript and final output repair/strip/check commands.
  Independent lookup-only runtime edits reuse A, including explicit editRuntime.
* Shared: Python, Coreutils, Bash, make and archive/text tools have explicit roles
  in A and packaging. assemblyStateScript is the separate A retention selector;
  assemblyScript is F-only. Packaging-code edits reuse the checkpoint/A.
* R/U: existing JNI/subprocess/font/image/jlink/jpackage/closure/version tests are
  independently factory-built. No upstream acceptance is added to production.

STRUCTURE.md explicitly recognizes pure reassembly over compiled products as F
packaging; raw installation and all compilation remain A. This is no waiver.

Later, one latest qualification builds A once and traces F to prove no compiler,
javac or bootstrap dispatch; validates native module hashes, release/src.zip/CDS,
embedded native loaders/RPATHs, JNI/subprocess/font/CUPS, generated jlink image and
real jpackage launcher; measures the retained manifest/size and excludes A from
all final bytes/links. Emitted native-map coverage, hash behavior and restoration
are still UNKNOWN. No package runtime qualification or strict success is claimed;
all nonpasses/hardening/full/machineReady/mergeEligible holds remain unwaived.
