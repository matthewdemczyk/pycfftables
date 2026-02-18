from libc.stdio cimport FILE

cdef extern from "libcfftables/libcfftables.h":
    ctypedef struct cff_t:
        pass
    cff_t* cff_alloc(int d, int t, long long n)
    void cff_free(cff_t *cff)
    cff_t* cff_copy(const cff_t *src)
    int cff_get_d(const cff_t *cff)
    int cff_get_t(const cff_t *cff)
    long long cff_get_n(const cff_t *cff)
    void cff_set_d(cff_t *cff, int d)
    int cff_get_matrix_value(const cff_t *cff, int r, int c)
    void cff_set_matrix_value(cff_t *cff, int r, int  c, int val)
    void cff_write(const cff_t *cff, FILE *file)
    bint cff_verify(const cff_t *cff)
    void cff_reduce_n(cff_t * cff, long long n)

    ctypedef struct cff_table_ctx_t:
        pass
    cff_table_ctx_t* cff_table_create(int d_maximum, int t_maximum, long long n_maximum)
    void cff_table_free(cff_table_ctx_t *ctx)
    cff_t* cff_table_get_by_t(cff_table_ctx_t *ctx, int d, int t)
    cff_t* cff_table_get_by_n(cff_table_ctx_t *ctx, int d, int n)

    cff_t* cff_identity(int d, int n)
    cff_t* cff_sperner(int n)
    cff_t* cff_sts(int v)
    cff_t* cff_fixed(int d, int t) #
    cff_t* cff_reed_solomon(int p, int exp, int t, int m)
    cff_t* cff_short_reed_solomon(int p, int exp, int t, int m, int s)
    cff_t* cff_porat_rothschild(int p, int a, int k, int r, int m)
    cff_t* cff_extend_by_one(const cff_t *cff)
    cff_t* cff_additive(const cff_t *left, const cff_t *right)
    cff_t* cff_doubling(const cff_t *cff, int s)
    cff_t* cff_kronecker(const cff_t *left, const cff_t *right)
    cff_t* cff_optimized_kronecker(const cff_t *kronecker_outer, const cff_t *kronecker_inner, const cff_t *bottom_cff)
    const unsigned char* cff_matrix_data(const cff_t *cff)
    long long cff_get_row_pitch_bits(const cff_t *cff)