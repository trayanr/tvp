#include <fftw3.h>
#include <math.h>
#include <stdio.h>

int main(void)
{
    enum { length = 8 };
    double input[length] = { 0.25, -1.0, 2.0, 3.0, 0.5, 4.0, -0.75, 0.0 };
    double result[length] = { 0 };
    fftw_complex spectrum[length / 2 + 1];
#ifdef THREADED
    if (!fftw_init_threads())
        return 1;
    fftw_plan_with_nthreads(2);
#endif
    fftw_plan forward = fftw_plan_dft_r2c_1d(length, input, spectrum, FFTW_ESTIMATE);
    fftw_plan inverse = fftw_plan_dft_c2r_1d(length, spectrum, result, FFTW_ESTIMATE);
    if (!forward || !inverse)
        return 1;
    fftw_execute(forward);
    fftw_execute(inverse);
    for (int i = 0; i < length; ++i) {
        if (!(fabs(result[i] / length - input[i]) < 1e-10))
            return 1;
    }
    fftw_destroy_plan(inverse);
    fftw_destroy_plan(forward);
#ifdef THREADED
    fftw_cleanup_threads();
#endif
    puts("FFT round trip");
    return 0;
}
