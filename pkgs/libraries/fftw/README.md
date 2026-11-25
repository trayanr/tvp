# FFTW build features

The default x86_64 Linux build installs double, single, extended and quad
precision libraries, with separate POSIX-thread and OpenMP libraries for each
precision. The single and double precision builds include the upstream SSE2,
AVX, AVX2 and AVX-512 codelets, selected at runtime. The build includes the
wisdom utilities, installed headers, pkg-config interfaces and manual pages.

FFTW supplies the C interfaces and Fortran wrappers from its release source.
A source-owned MPI provider is required for the optional FFTW MPI library.
