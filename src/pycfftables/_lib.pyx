from pycfftables._lib cimport *
from libc.stdio cimport FILE, fopen, fclose
from pathlib import Path

cdef class CFF:
    cdef cff_t* _c_cff

    def __cinit__(self):
        self._c_cff = NULL

    def __init__(self):
        if self._c_cff == NULL:
            raise TypeError(
                "Cannot create CFF directly. "
                "Use CFFTable.get_by_t(), get_by_n(), or a construction method"
            )

    def __dealloc__(self):
        if self._c_cff != NULL:
            cff_free(self._c_cff)

    @property
    def d(self):
        if self._c_cff == NULL:
            raise ValueError("CFF not initialized")
        return cff_get_d(self._c_cff)

    @d.setter
    def d(self, int value):
        if self._c_cff == NULL:
            raise ValueError("CFF not initialized")
        cff_set_d(self._c_cff, value)

    @property
    def t(self):
        if self._c_cff == NULL:
            raise ValueError("CFF not initialized")
        return cff_get_t(self._c_cff)

    @property
    def n(self):
        if self._c_cff == NULL:
            raise ValueError("CFF not initialized")
        return cff_get_n(self._c_cff)

    def get_value(self, int r, int c):
        return cff_get_matrix_value(self._c_cff, r, c)

    def set_value(self, int r, int c, int val):
        cff_set_matrix_value(self._c_cff, r, c, val)

    def verify(self):
        return bool(cff_verify(self._c_cff))

    def print(self):
        cff_print(self._c_cff)

    def write(self, filepath):
        if self._c_cff == NULL:
            raise ValueError("CFF not initialized")

        py_path = str(filepath).encode('utf-8')
        c_file = fopen(py_path, b"w")
        if c_file == NULL:
            raise IOError(f"Cannot open file: {filepath}")

        try:
            cff_write(self._c_cff, c_file)
        finally:
            fclose(c_file)

    @staticmethod
    def all_zeros(int d, int t, int n):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_alloc(d, t, n)
        if result._c_cff == NULL:
            raise MemoryError("Failed to allocate CFF")
        return result

    @staticmethod
    def identity(int d, int n):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_identity(d, n)
        if result._c_cff == NULL:
            raise ValueError("")
        return result

    @staticmethod
    def sperner(int n):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_sperner(n)
        if result._c_cff == NULL:
            raise ValueError("")
        return result

    @staticmethod
    def sts(int v):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_sts(v)
        if result._c_cff == NULL:
            raise ValueError("")
        return result

cdef class CFFTable:
    cdef cff_table_ctx_t* _c_cff_table_ctx

    def __cinit__(self, int d_maximum, int t_maximum, long long n_maximum):
        self._c_cff_table_ctx = cff_table_create(d_maximum, t_maximum, n_maximum)
        if self._c_cff_table_ctx == NULL:
            raise MemoryError("Failed to allocate CFFTable")

    def __dealloc__(self):
        if self._c_cff_table_ctx != NULL:
            cff_table_free(self._c_cff_table_ctx)
            self._c_cff_table_ctx = NULL

    def get_by_t(self, int d, int t):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_table_get_by_t(self._c_cff_table_ctx, d, t)
        if result._c_cff == NULL:
            return None
        return result

    def get_by_n(self, int d, int n):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_table_get_by_n(self._c_cff_table_ctx, d, n)
        if result._c_cff == NULL:
            return None
        return result