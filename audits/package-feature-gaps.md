# Package feature follow-ups

The recipe audit uses master `015706c` as its baseline. These items cover
features that need a new provider, a user-facing profile decision, or an
installed compatibility check before widening the default build.

| Area | Work to discuss |
| --- | --- |
| GCC and LLVM | Decide which additional compiler frontends, multilib targets, LLVM runtimes, and projects should be selectable together. Start LLVM compatibility testing with the historical PostgreSQL JIT providers in [#394](https://github.com/trayanr/tvp/pull/394). Libedit, performance counters, and Z3 need providers. |
| Java, Flutter, and Android | Preserve the headless JDK profile and qualify a desktop AWT/Swing build with the X11 runtime. Flutter desktop needs its native desktop build dependencies. Android emulator support also needs a host binary and appropriate system images. |
| GTK and text rendering | Coordinate HarfBuzz, FriBidi, Pixman, Cairo, GLib, Pango, librsvg, and libraqm. They affect ImageMagick, FreeType, Fontconfig, and a public Graphviz build. |
| Image and document formats | Ghostscript is needed for PDF and PostScript rasterization. HEIC/AVIF needs libheif and its codecs. JPEG XL needs libjxl after [Brotli and Highway](https://github.com/trayanr/tvp/pull/393). FFTW, LibRaw, and Ultra HDR have standalone prerequisite PRs. Older ImageMagick releases also need compatible historical PNG, LCMS, or JPEG 2000 interfaces. |
| Python, Perl, and Git | Tk unlocks Tkinter and Git GUI/Gitk. Berkeley DB covers Python's historical bsddb and Perl's DB_File. Python's native UUID module can use the proposed libuuid after [#389](https://github.com/trayanr/tvp/pull/389). Perl interpreter threads change the build ABI and need consumer checks. |
| PHP | Qualify the PHP-FPM daemon and its packaging separately. Add version-bound selectable FFI and XSL extensions with existing libffi and libxslt. PHP GD still needs AVIF and XPM providers. MongoDB's Snappy, SASL, and field-level encryption need provider work. |
| Redis modules | Package jemalloc and the Redis Search, JSON, Bloom, and TimeSeries modules with explicit source inputs. Service integration depends on a systemd provider. |
| System and developer tools | Guile is needed by GNU Make's scripting API, Qt by cmake-gui, and libseccomp by File's sandbox. Libselinux can serve both GNU tar and other SELinux consumers. Fontconfig translations and Fontations warrant separate qualification. |

## Package checks to preserve

- ImageMagick must exercise SVG rasterization, PNG/JPEG/BMP/ICO, multi-frame
  GIF, and the installed `convert` and `identify` commands. The package and
  the original application format check both need passing results.
- Keep exact TVP PostgreSQL 11.9 source coverage, including its selected
  OpenSSL and libxml2 runtime. Run the installed SQL test and the application
  boot check on the resulting package.
- Keep ImageMagick and Nokogiri on compatible XML providers. Check the exact
  loaded Nokogiri libraries as well as XML parsing and XSLT in the application.
- For PostgreSQL Bonjour, start from TVP's existing `libdns_sd` client
  library. A self-contained discovery test also needs an mDNS daemon.

UnZip 6.0's Bzip2 configure path specifically expects a library built with
`BZ_NO_STDIO`; the public CLI-oriented Bzip2 output requires a separate
compatibility decision before enabling that path. SQLite's CLI ZIP support
also needs a deliberate update to the existing zlib-free build contract.
