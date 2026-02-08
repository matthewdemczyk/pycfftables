from pycfftables._lib cimport *
from libc.stdio cimport FILE, fopen, fclose, fdopen, fflush
from cpython.object cimport PyObject

from math import comb, floor
from os import dup as os_dup, close as os_close

cdef class CFF:
    '''
    A Cover-Free Family (CFF) stored as an incidence matrix using a bit field.

    A d-CFF(t,n) is a t*n binary matrix where no column is covered by
    the union of any d other columns.

    This class wraps the libcfftables C library and provides a Pythonic
    interface for working with CFFs.

    Initializing a CFF
    ------------------

    A CFF is normally instantiated by using :meth:`CFFTable.get_by_t()` or :meth:`CFFTable.get_by_n()`.
    First a :class:`CFF_Table` should be created by providing the maximum d, t, and n you will need.

    Create a CFFTable and construct a CFF:

    >>> table = CFFTable(d_max = 3, t_max = 100, n_max = 10000)
    >>> cff = table.get_by_t(d = 3, t = 20)
    >>> cff
    3-CFF(20,25)

    >>> cff = table.get_by_n(d = 2, n = 12)
    >>> cff
    2-CFF(9,12)

    Alternatively you can create a CFF from a direct construction:

    >>> cff = CFF.sperner(6)
    >>> print(cff)
    1-CFF(4,6):
    1 1 1 - - -
    1 - - 1 1 -
    - 1 - 1 - 1
    - - 1 - 1 1

    After initializing one or more CFFs, recursive constructions can be used:

    >>> cff = CFF.sts(9)
    >>> CFF.double(cff)
    2-CFF(17,24)

    There are 5 ways to view the elements of the CFF:

        - The the group testing pools can be iterated over or indexed  with :attribute:`CFF.pools`
        - The subsets of the set system can be iterated over or indexed with :attribute:`CFF.subsets`
        - The columns can be iterated over or indexed with :attribute:`CFF.cols`
        - The rows can be iterated over or indexed with :attribute:`CFF.rows`
        - The cells can be read or written to directly by indexing by a 2-tuple

    Here are examples:

    Iterate over the group testing pools of a CFF:

    >>> cff = CFF.sperner(6)
    >>> for i in cff.pools: print(i)
    (0, 1, 2)
    (0, 3, 4)
    (1, 3, 5)
    (2, 4, 5)

    Iterate over the subsets of the CFF:

    >>> cff = CFF.sperner(6)
    >>> for i in cff.subsets: print(i)
    (0, 1)
    (0, 2)
    (0, 3)
    (1, 2)
    (1, 3)
    (2, 3)

    Iterate over the columns of the CFF:

    >>> cff = CFF.sperner(6)
    >>> for i in cff.cols: print(i)
    (1, 1, 0, 0)
    (1, 0, 1, 0)
    (1, 0, 0, 1)
    (0, 1, 1, 0)
    (0, 1, 0, 1)
    (0, 0, 1, 1)

    Iterate over the rows of the CFF:

    >>> cff = CFF.sperner(6)
    >>> for i in cff.rows: print(i)
    (1, 1, 1, 0, 0, 0)
    (1, 0, 0, 1, 1, 0)
    (0, 1, 0, 1, 0, 1)
    (0, 0, 1, 0, 1, 1)

    Access matrix elements:

    >>> cff[0, 0]  # Get element at row 0, col 0
    1
    >>> cff[0, 0] = 0  # Set element


    Notes
    -----
    CFF objects cannot be created directly. Use the static construction
    methods like :meth:`sperner`, :meth:`identity`, or retrieve from
    a :class:`CFFTable` using :meth:`~pycfftables.CFFTable.get_by_t` or :meth:`~pycfftables.CFFTable.get_by_n`.
    '''
    cdef cff_t* _c_cff

    # struct members of a cff_t
    cdef const unsigned char* _matrix
    cdef int _row_pitch_bits
    cdef int _d
    cdef int _t
    cdef int _n

    def __cinit__(self):
        self._c_cff = NULL

    def __init__(self):
        if self._c_cff == NULL:
            raise TypeError(
                'Cannot create CFF directly. '
                'Use CFFTable.get_by_t(), get_by_n(), or a construction method'
            )

    def __dealloc__(self):
        if self._c_cff != NULL:
            cff_free(self._c_cff)

    cdef void _cache_layout(self):
        self._matrix = cff_matrix_data(self._c_cff)
        if self._matrix == NULL:
            raise ValueError("Failed to get matrix data")

        self._row_pitch_bits = cff_get_row_pitch_bits(self._c_cff)
        self._d = cff_get_d(self._c_cff)
        self._t = cff_get_t(self._c_cff)
        self._n = cff_get_n(self._c_cff)

    @property
    def d(self):
        '''
        The d parameter of this d-CFF(t,n).

        This can be set to check if a d-CFF is also a (d+1)-CFF using
        the :meth:`verify` method.

        Returns
        -------
        int
            The d value.
        '''
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')
        return cff_get_d(self._c_cff)

    @d.setter
    def d(self, int value):
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')
        cff_set_d(self._c_cff, value)

    @property
    def t(self):
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')
        return cff_get_t(self._c_cff)

    @property
    def n(self):
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')
        return cff_get_n(self._c_cff)

    @property
    def shape(self):
        return (self.t, self.n)

    @property
    def rows(self):
        return _RowsView(self)

    @property
    def cols(self):
        return _ColsView(self)

    @property
    def subsets(self):
        return _SubsetsView(self)

    @property
    def pools(self):
        return _PoolsView(self)

    def get_value(self, int r, int c):
        return cff_get_matrix_value(self._c_cff, r, c)

    def set_value(self, int r, int c, int val):
        cff_set_matrix_value(self._c_cff, r, c, val)

    def __getitem__(self, key):
        '''
        Get a matrix element using indexing syntax: cff[row, col].

        Parameters
        ----------
        key : tuple of (int, int)
            Row and column indices.

        Returns
        -------
        int
            The value (0 or 1) at the specified position.

        Raises
        ------
        TypeError
            If key is not a 2-tuple.

        Examples
        --------
        >>> cff = CFF.sperner(6)
        >>> cff[0, 0]
        1
        '''
        if isinstance(key, tuple) and len(key) == 2:
            r, c = key
            return self.get_value(r, c)
        else:
            raise TypeError('CFF indexing requires a tuple of (row, col)')

    def __setitem__(self, key, value):
        if value != 0 and value != 1:
            raise TypeError('CFF cells can only be set to 0 or 1')
        if isinstance(key, tuple) and len(key) == 2:
            r, c = key
            self.set_value(r, c, value)
        else:
            raise TypeError('CFF indexing requires a tuple of (row, col)')

    def __repr__(self):
        if self._c_cff == NULL:
            return 'CFF(uninitialized)'
        return f'{self.d}-CFF({self.t},{self.n})'

    def __str__(self):
        if self._c_cff == NULL:
            return 'CFF(uninitialized)'

        lines = [f'{self.d}-CFF({self.t},{self.n}):']
        for r in range(self.t):
            row = []
            for c in range(self.n):
                value = self[r, c]
                row.append('1' if value else '-')
            lines.append(' '.join(row))

        return '\n'.join(lines)

    def verify(self):
        return bool(cff_verify(self._c_cff))

    def write_to_filepath(self, filepath):
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')

        py_path = str(filepath).encode('utf-8')
        c_file = fopen(py_path, b'w')
        if c_file == NULL:
            raise IOError(f'Cannot open file: {filepath}')

        try:
            cff_write(self._c_cff, c_file)
        finally:
            fclose(c_file)


    def write_to_file_obj(self, file_obj):
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')

        cdef int fd = file_obj.fileno()
        cdef int fd_copy = os_dup(fd)

        cdef FILE* c_file = fdopen(fd_copy, b'w')
        if c_file == NULL:
            os_close(fd_copy)
            raise IOError('Failed to convert file object to C FILE*')

        try:
            cff_write(self._c_cff, c_file)
            fflush(c_file)
        finally:
            fclose(c_file)

    def copy(self) -> CFF:
        cdef CFF dst = CFF.__new__(CFF)
        dst._c_cff = cff_copy(self._c_cff)
        if dst._c_cff == NULL:
            raise MemoryError('Failed to copy CFF')
        dst._cache_layout()
        return dst

    @staticmethod
    def all_zeros(int d, int t, int n) -> CFF:
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_alloc(d, t, n)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize all zeros CFF')
        result._cache_layout()
        return result

    @staticmethod
    def identity(int d, int n) -> CFF:
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_identity(d, n)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF from identity matrix')
        result._cache_layout()
        return result

    @staticmethod
    def sperner(int n) -> CFF:
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_sperner(n)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize 1-CFF from Sperner system')
        result._cache_layout()
        return result

    @staticmethod
    def sts(int v):
        cdef CFF result = CFF.__new__(CFF)
        if not ((v % 6 == 3) or (v % 6 == 1)):
            raise ValueError('v parameter must be congruent to 1,3 mod 6 to create STS')
        result._c_cff = cff_sts(v)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize 2-CFF from STS')
        result._cache_layout()
        return result

    @staticmethod
    def reed_solomon(int p, int exp, int k, int m):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_reed_solomon(p, exp, k, m)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF from Reed-Solomon code')
        result._cache_layout()
        return result

    @staticmethod
    def short_reed_solomon(int p, int exp, int k, int m, int s):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_short_reed_solomon(p, exp, k, m, s)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF from short Reed-Solomon code')
        result._cache_layout()
        return result

    @staticmethod
    def porat_rothschild(int p, int exp, int k, int r, int m):
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_porat_rothschild(p, exp, k, r, m)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF from Porat & Rothschild code')
        result._cache_layout()
        return result

    @staticmethod
    def extend_by_one(to_extend):
        cdef CFF result = CFF.__new__(CFF)
        cdef CFF c_to_extend = to_extend
        result._c_cff = cff_extend_by_one(c_to_extend._c_cff)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF using extend by one construction')
        result._cache_layout()
        return result

    @staticmethod
    def add(left, right):
        cdef CFF result = CFF.__new__(CFF)
        cdef CFF c_left = left
        cdef CFF c_right = right
        result._c_cff = cff_additive(c_left._c_cff, c_right._c_cff)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF using additive construction')
        result._cache_layout()
        return result

    @staticmethod
    def double(to_double):
        if not to_double.d == 2: raise ValueError('Can only double a 2-CFF')
        cdef CFF result = CFF.__new__(CFF)
        cdef CFF c_to_double = to_double
        cdef int n = cff_get_n(c_to_double._c_cff)
        cdef int s = 0
        while comb(s,floor(s/2)) <= n:
            s += 1
        result._c_cff = cff_doubling(c_to_double._c_cff, s)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF using additive construction')
        result._cache_layout()
        return result

    @staticmethod
    def kronecker(left, right):
        cdef CFF result = CFF.__new__(CFF)
        cdef CFF c_left = left
        cdef CFF c_right = right
        result._c_cff = cff_kronecker(c_left._c_cff, c_right._c_cff)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF using Kronecker construction')
        result._cache_layout()
        return result

    @staticmethod
    def optimized_kronecker(outer, inner, bottom):
        if not (bottom.d == inner.d): raise ValueError('Inner and outer d must match')
        if not (bottom.d == outer.d-1): raise ValueError('Outer d must be 1 less than bottom and inner CFF d')
        cdef CFF result = CFF.__new__(CFF)
        cdef CFF c_outer = outer
        cdef CFF c_inner = inner
        cdef CFF c_bottom = bottom
        result._c_cff = cff_optimized_kronecker(c_outer._c_cff, c_inner._c_cff, c_bottom._c_cff)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF using optimized Kronecker construction')
        result._cache_layout()
        return result


cdef class _ColsView:
    cdef CFF _cff

    def __cinit__(self, CFF cff):
        self._cff = cff

    def __len__(self):
        return self._cff._n

    def __getitem__(self, int c):
        cdef int r, bit_offset, byte_idx, bit_idx
        cdef int t = self._cff._t
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        if c < 0:
            c += self._cff._n

        if c < 0 or c >= self._cff._n:
            raise IndexError('Column index out of bounds')

        col = bytearray(t)
        for r in range(t):
            bit_offset = r * pitch + c
            byte_idx = bit_offset >> 3
            bit_idx = bit_offset & 7
            col[r] = (data[byte_idx] >> bit_idx) & 1

        return tuple(col)

    def __iter__(self):
        cdef int r, c
        cdef int bit_offset, byte_idx, bit_idx
        cdef int t = self._cff._t
        cdef int n = self._cff._n
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        for c in range(n):
            col = bytearray(t)
            for r in range(t):
                bit_offset = r * pitch + c
                byte_idx = bit_offset >> 3
                bit_idx = bit_offset & 7
                col[r] = (data[byte_idx] >> bit_idx) & 1
            yield tuple(col)


cdef class _RowsView:
    cdef CFF _cff

    def __cinit__(self, CFF cff):
        self._cff = cff

    def __len__(self):
        return self._cff._t

    def __getitem__(self, int r):
        cdef int c, bit_offset, byte_idx, bit_idx
        cdef int n = self._cff._n
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        if r < 0:
            r += self._cff._t

        if r < 0 or r >= self._cff._t:
            raise IndexError('Row index out of bound')

        row = bytearray(n)
        for c in range(n):
            bit_offset = r * pitch + c
            byte_idx = bit_offset >> 3
            bit_idx = bit_offset & 7
            row[c] = (data[byte_idx] >> bit_idx) & 1

        return tuple(row)

    def __iter__(self):
        cdef int r, c
        cdef int bit_offset, byte_idx, bit_idx
        cdef int t = self._cff._t
        cdef int n = self._cff._n
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        for r in range(t):
            row = bytearray(n)
            bit_offset = r * pitch
            for c in range(n):
                byte_idx = bit_offset >> 3
                bit_idx = bit_offset & 7
                row[c] = (data[byte_idx] >> bit_idx) & 1
                bit_offset += 1
            yield tuple(row)


cdef class _PoolsView:
    cdef CFF _cff

    def __cinit__(self, CFF cff):
        self._cff = cff

    def __len__(self):
        return self._cff._t

    def __getitem__(self, int r):
        cdef int c, bit_offset, byte_idx, bit_idx
        cdef int n = self._cff._n
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        if r < 0:
            r += self._cff._t

        if r < 0 or r >= self._cff._t:
            raise IndexError('pool index out of range')

        result = []
        bit_offset = r * pitch
        for c in range(n):
            byte_idx = bit_offset >> 3
            bit_idx = bit_offset & 7
            if (data[byte_idx] >> bit_idx) & 1:
                result.append(c)
            bit_offset += 1

        return tuple(result)

    def __iter__(self):
        cdef int r, c
        cdef int bit_offset, byte_idx, bit_idx
        cdef int t = self._cff._t
        cdef int n = self._cff._n
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        for r in range(t):
            result = []
            bit_offset = r * pitch
            for c in range(n):
                byte_idx = bit_offset >> 3
                bit_idx = bit_offset & 7
                if (data[byte_idx] >> bit_idx) & 1:
                    result.append(c)
                bit_offset += 1
            yield tuple(result)


cdef class _SubsetsView:
    cdef CFF _cff

    def __cinit__(self, CFF cff):
        self._cff = cff

    def __len__(self):
        return self._cff._n

    def __getitem__(self, int c):
        cdef int r, bit_offset, byte_idx, bit_idx
        cdef int t = self._cff._t
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        if c < 0 or c >= self._cff._n:
            raise IndexError('Column index out of bounds')

        if c < 0 or c >= self._cff._n:
            raise IndexError("set index out of range")

        result = []
        for r in range(t):
            bit_offset = r * pitch + c
            byte_idx = bit_offset >> 3
            bit_idx = bit_offset & 7
            if (data[byte_idx] >> bit_idx) & 1:
                result.append(r)

        return tuple(result)

    def __iter__(self):
        cdef int r, c
        cdef int bit_offset, byte_idx, bit_idx
        cdef int t = self._cff._t
        cdef int n = self._cff._n
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        for c in range(n):
            result = []
            for r in range(t):
                bit_offset = r * pitch + c
                byte_idx = bit_offset >> 3
                bit_idx = bit_offset & 7
                if (data[byte_idx] >> bit_idx) & 1:
                    result.append(r)
            yield tuple(result)


cdef class CFFTable:
    cdef cff_table_ctx_t* _c_cff_table_ctx
    cdef int _d_maximum
    cdef int _t_maximum
    cdef long long _n_maximum

    def __cinit__(self, int d_max, int t_max, long long n_max):
        self._d_maximum = d_max
        self._t_maximum = t_max
        self._n_maximum = n_max
        self._c_cff_table_ctx = cff_table_create(d_max, t_max, n_max)
        if self._c_cff_table_ctx == NULL:
            raise MemoryError('Failed to allocate CFFTable')

    def __dealloc__(self):
        if self._c_cff_table_ctx != NULL:
            cff_table_free(self._c_cff_table_ctx)
            self._c_cff_table_ctx = NULL

    @property
    def d_max(self):
        return self._d_maximum

    @property
    def t_max(self):
        return self._t_maximum

    @property
    def n_max(self):
        return self._n_maximum

    def get_by_t(self, int d, int t) -> CFF | None:
        '''
        Construct a CFF from the tables

        Parameters
        ----------
        d : int
            the d parameter of the desired cover-free family
        t : int
            the number of rows in the CFF's incidence matrix (the length of the CFF's ground set)

        Returns
        -------
        CFF | None
            A CFF with the desired d and t, with maximum n from our constructions, or None on failure
        '''
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_table_get_by_t(self._c_cff_table_ctx, d, t)
        if result._c_cff == NULL:
            return None
        result._cache_layout()
        return result

    def get_by_n(self, int d, int n) -> CFF | None:
        '''
        Construct a CFF using the tables by providing the d and n parameters desired

        Note that not every unique n value appears in the tables. This function will likely return
        a CFF with larger n, but the extra columns can be ignored and the CFF still has the cover-free
        property.

        Parameters
        ----------
        d : int
            the d parameter of the desired cover-free family
        n : int
            The number of columns in the CFF's incidence matrix (the number of subset in its set system)

        Returns
        -------
        CFF | None
            A CFF with the desired t and n, possibly with n larger, and minimum t from our constructions, or None on failure
        '''
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_table_get_by_n(self._c_cff_table_ctx, d, n)
        if result._c_cff == NULL:
            return None
        result._cache_layout()
        return result