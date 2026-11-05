int c_sum(const int *values, int count) {
    int result = 0, i;
    for (i = 0; i < count; ++i) result += values[i];
    return result;
}
