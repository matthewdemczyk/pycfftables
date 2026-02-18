from pycfftables._lib cimport *
from libc.stdio cimport FILE, fopen, fclose, fdopen, fflush
from cpython.object cimport PyObject

from math import comb, floor
from os import dup as os_dup, close as os_close
from typing import Iterator

cdef class CFF:
    """
    A cover-free family (CFF) stored as an incidence matrix using a bit field.

    A cover-free family, denoted `d-CFF(t,n)` is a set system where the ground set has `t` elements,
    the set system contains `n` subsets, and no subset is contained in the union of any `d` other subsets.

    This class wraps the libcfftables C library and provides a Pythonic
    interface for working with CFFs.

    Initializing a CFF
    ------------------

    A CFF is normally instantiated by using :meth:`CFFTable.get_by_t()` or :meth:`CFFTable.get_by_n()`.
    First a :class:`CFF_Table` should be created by providing the maximum d, t, and n you will need.

    Create a CFFTable and construct a CFF by providing the desired d and t values:

    >>> table = CFFTable(d_max = 3, t_max = 100, n_max = 10000)
    >>> cff = table.get_by_t(d = 3, t = 20)
    >>> cff
    3-CFF(20,25)

    Alternatively, construct a CFF by providing the desired d and n values:

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
    >>> new_cff = CFF.double(cff)
    >>> new_cff
    2-CFF(17,24)


    Notes
    -----
    CFF objects are not constructed by calling CFF(). Use the static factory
    methods like :meth:`sperner`, :meth:`identity`, or retrieve from
    a :class:`CFFTable` using :meth:`~pycfftables.CFFTable.get_by_t` or :meth:`~pycfftables.CFFTable.get_by_n`.
    """
    cdef cff_t* _c_cff

    # struct members of a cff_t
    cdef const unsigned char* _matrix
    cdef long long _row_pitch_bits
    cdef int _d
    cdef int _t
    cdef long long _n

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
        """
        Internal method to make copies of the cff_t struct's values in python

        The reason to do this is because the C api only exposes getter functions
        and not the attributes themselves, so by storing them them we're avoiding making
        unneeded C function calls.

        The row pitch bits is used in the view classes
        """
        self._matrix = cff_matrix_data(self._c_cff)
        if self._matrix == NULL:
            raise ValueError('Failed to get matrix data')

        self._row_pitch_bits = cff_get_row_pitch_bits(self._c_cff)
        self._d = cff_get_d(self._c_cff)
        self._t = cff_get_t(self._c_cff)
        self._n = cff_get_n(self._c_cff)

    cdef void _reduce_cff_n(self, long long new_n):
        """
        Calls libcfftables' reduce n function to remove some columns of a CFF
        the extra columns are still stored in memory, but aren't accessed.
        """
        cff_reduce_n(self._c_cff, new_n)

    @property
    def d(self):
        """
        The d parameter of this d-CFF(t,n).

        This can be changed by assigning to this property.
        Changing the d of a CFF can be useful to check if a d-CFF is
        also a (d+1)-CFF using the :meth:`verify` method.

        Raises
        ------
        ValueError
            If the CFF has not been initialized

        Returns
        -------
        int
            The d value.
        """
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
        """
        The t of a d-CFF(t,n)

        This is the size of the ground set, also known as the number
        of rows of the incidence matrix.

        Raises
        ------
        ValueError
            If the CFF has not been initialized

        Returns
        -------
        int
            The t value
        """
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')
        return cff_get_t(self._c_cff)

    @property
    def n(self):
        """
        The n of a d-CFF(t,n)

        This is the number of subsets of a CFF's set system, also
        known as the number of columns of the incidence matrix.

        Raises
        ------
        ValueError
            If the CFF has not been initialized

        Returns
        -------
        int
            The t value
        """
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')
        return cff_get_n(self._c_cff)

    @property
    def shape(self):
        """
        The (rows, columns) of a CFF.

        The number of rows is the t property of a CFF, and
        the number of columns is the n property of a CFF.

        Raises
        ------
        ValueError
            If the CFF has not been initialized

        Returns
        -------
        tuple[int, int]
            The (rows, columns) of a CFF
        """
        if self._c_cff == NULL:
            raise ValueError('CFF not initialized')
        return (self.t, self.n)

    @property
    def rows(self):
        """
        View of the CFF as rows.

        Supports indexing and iteration. Each row is returned as a tuple of 0s and 1s
        of length n. There are t rows.

        Example
        -------
        Iterate over the rows of the CFF:

        >>> cff = CFF.sts(9)
        >>> for i in cff.rows: print(i)
        ...
        (1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0)
        (0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0)
        (0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1)
        (1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0)
        (0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0)
        (0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1)
        (1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0)
        (0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0)
        (0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1)

        Returns
        -------
        RowsView
            A view object that can be indexed or iterated over
        """
        return RowsView(self)

    @property
    def cols(self):
        """
        View of the CFF as columns.

        Supports indexing and iteration. Each column is returned as a tuple of 0s and 1s
        of length t. There are n columns.


        Example
        -------
        Iterate over the columns of the CFF:

        >>> cff = CFF.sts(9)
        >>> for i in cff.cols: print(i)
        ...
        (1, 0, 0, 1, 0, 0, 1, 0, 0)
        (1, 1, 0, 0, 0, 1, 0, 0, 0)
        (0, 0, 0, 1, 1, 0, 0, 0, 1)
        (0, 0, 1, 0, 0, 0, 1, 1, 0)
        (1, 0, 1, 0, 1, 0, 0, 0, 0)
        (0, 0, 0, 1, 0, 1, 0, 1, 0)
        (0, 1, 0, 0, 0, 0, 1, 0, 1)
        (0, 1, 0, 0, 1, 0, 0, 1, 0)
        (0, 1, 1, 1, 0, 0, 0, 0, 0)
        (0, 0, 0, 0, 1, 1, 1, 0, 0)
        (1, 0, 0, 0, 0, 0, 0, 1, 1)
        (0, 0, 1, 0, 0, 1, 0, 0, 1)


        Returns
        -------
        ColsView
            A view object that can be indexed or iterated over
        """
        return ColsView(self)

    @property
    def subsets(self):
        """
        View of the CFF as subsets.

        Supports indexing and iteration. Each subset is returned as a tuple of values in [0, t-1].
        There are n subsets.

        Example
        -------
        Iterate over the subsets of the CFF:

        >>> cff = CFF.sts(9)
        >>> for i in cff.subsets: print(i)
        ...
        (0, 3, 6)
        (0, 1, 5)
        (3, 4, 8)
        (2, 6, 7)
        (0, 2, 4)
        (3, 5, 7)
        (1, 6, 8)
        (1, 4, 7)
        (1, 2, 3)
        (4, 5, 6)
        (0, 7, 8)
        (2, 5, 8)


        Returns
        -------
        SubsetsView
            A view object that can be indexed or iterated over
        """
        return SubsetsView(self)

    @property
    def pools(self):
        """
        View of the CFF as group testing pools.

        Supports indexing and iteration. Each pool is returned as a tuple of values in [0, n-1].
        There are t pools.

        Example
        -------
        Iterate over the group testing pools of a CFF:

        >>> cff = CFF.sts(9)
        >>> for i in cff.pools: print(i)
        ...
        (0, 1, 4, 10)
        (1, 6, 7, 8)
        (3, 4, 8, 11)
        (0, 2, 5, 8)
        (2, 4, 7, 9)
        (1, 5, 9, 11)
        (0, 3, 6, 9)
        (3, 5, 7, 10)
        (2, 6, 10, 11)


        Returns
        -------
        PoolsView
            A view object that can be indexed or iterated over
        """
        return PoolsView(self)

    def __getitem__(self, key):
        """
        Get a matrix element using indexing syntax: cff[row, col].

        Parameter
        ---------
        key : tuple[int, int]
            A 2-tuple of (row, col) to index

        Raises
        ------
        TypeError
            If key is not a 2-tuple of integers
        IndexError
            If row or column is out of bounds

        Returns
        -------
        int
            The matrix value, a 0 or 1, at position (row, col)


        Examples
        --------
        >>> cff = CFF.sts(9)
        >>> cff[0, 0]
        1
        """
        if isinstance(key, tuple) and len(key) == 2 and type(key[0]) == int and type(key[1]) == int:
            r, c = key
            if r < 0 or r >= self._t or c < 0 or c >= self._n:
                raise IndexError('Indexed the CFF out of bounds')
            return cff_get_matrix_value(self._c_cff, r, c)
        else:
            raise TypeError('CFF indexing requires a tuple of (row, col)')

    def __setitem__(self, key, value):
        """
        Set a matrix element using indexing syntax: cff[row, col] = value

        Parameters
        ----------
        key : tuple[int, int]
            The row and column of the CFF to set
        value : int
            The value, 0 or 1, to set the CFF cell to

        Raises
        ------
        TypeError
            If trying to assign something besides a zero or one, or if key is not a 2-tuple of integers
        IndexError
            If indexing the CFF out of bounds

        Examples
        --------
        >>> cff = CFF.sts(9)
        >>> cff[0,0] = 1
        """
        if value != 0 and value != 1:
            raise TypeError('CFF cells can only be set to 0 or 1')
        if isinstance(key, tuple) and len(key) == 2 and type(key[0]) == int and type(key[1]) == int:
            r, c = key
            if r < 0 or r >= self._t or c < 0 or c >= self._n:
                raise IndexError('Indexed the CFF out of bounds')
            cff_set_matrix_value(self._c_cff, r, c, value)
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

    def verify(self) -> bool:
        """
        Verify if a CFF is valid

        This function will iterate over every d+1
        subset of columns, and ensure that each 1-weight
        d+1 tuple appears

        Raises
        ------
        ValueError
            If self is not initialized
        IOError
            If the filepath cannon be opened

        Returns
        -------
        bool
            True if the CFF is valid, false otherwise
        """
        return bool(cff_verify(self._c_cff))

    def write_to_filepath(self, filepath) -> None:
        """
        Writes a CFF to a file

        Parameters
        ----------
        filepath : str
            The location to write the file to

        Raises
        ------
        ValueError
            If the cff is not initialized
        IOError
            If the file cannot be opened
        """
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

    def copy(self) -> CFF:
        """
        Make a copy of a CFF

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            The newly copied CFF
        """
        cdef CFF dst = CFF.__new__(CFF)
        dst._c_cff = cff_copy(self._c_cff)
        if dst._c_cff == NULL:
            raise MemoryError('Failed to copy CFF')
        dst._cache_layout()
        return dst

    @staticmethod
    def all_zeros(int d, int t, int n) -> CFF:
        """
        Constructs a d-CFF(t,n) filled with zeros.

        The is not a valid CFF and its values must be set
        somehow to make a valid CFF. This can be useful
        if you want to initialize a CFF from your own construction
        or an explicit CFF.

        Parameters
        ----------
        d : int
            The d parameter of the CFF
        t : int
            The number of rows of the CFF
        n : int
            The number of columns of the CFF

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            The newly constructed CFF
        """
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_alloc(d, t, n)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize all zeros CFF')
        result._cache_layout()
        return result

    @staticmethod
    def identity(int d, int n) -> CFF:
        """
        Constructs a d-CFF(n, n) from an identity matrix

        Parameters
        ----------
        d : int
            The d parameter of the CFF
        n : int
            The number of rows and columns of the CFF

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            The newly constructed CFF
        """
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_identity(d, n)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF from identity matrix')
        result._cache_layout()
        return result

    @staticmethod
    def sperner(int n) -> CFF:
        """
        Constructs a 1-CFF from a Sperner system.

        Parameters
        ----------
        n : int
            Number of subsets in the sperner system/CFF.

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            A 1-CFF(t = min{s : choose(s, s/2) >= n }, n)
        """
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_sperner(n)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize 1-CFF from Sperner system')
        result._cache_layout()
        return result

    @staticmethod
    def sts(int v) -> CFF:
        """
        Constructs a 2-CFF from a Steiner Triple System.

        Parameters
        ----------
        v : int
            Order of the STS. Must be congruent to 1,3 mod 6

        Raises
        ------
        MemoryError
            If CFF allocation failed
        ValueError
            If v is not congruent to 1,3 mod 6

        Returns
        -------
        CFF
            A 2-CFF(v, (v * (v - 1)) / 6)
        """
        cdef CFF result = CFF.__new__(CFF)
        if not ((v % 6 == 3) or (v % 6 == 1)):
            raise ValueError('v parameter must be congruent to 1,3 mod 6 to create STS')
        result._c_cff = cff_sts(v)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize 2-CFF from STS')
        result._cache_layout()
        return result

    @staticmethod
    def reed_solomon(int p, int exp, int k, int m) -> CFF:
        """
        Constructs a CFF from a Reed-Solomon error correcting code.

        Parameters
        ----------
        p : int
            The prime of the alphabet.
        exp : int
            The power of the alphabet.
        t : int
            Message length of the Reed-Solomon code.
        m : int
            Codeword size of the Reed-Solomon code.

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            A ((m - 1) / (t + 1))-CFF(m*(p^exp), (p^exp)^t)
        """
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_reed_solomon(p, exp, k, m)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF from Reed-Solomon code')
        result._cache_layout()
        return result

    @staticmethod
    def short_reed_solomon(int p, int exp, int k, int m, int s) -> CFF:
        """
        Constructs a CFF from a shortened Reed-Solomon error correcting code.

        Parameters
        ----------
        p : int
            The prime of the alphabet.
        exp : int
            The power of the alphabet.
        t : int
            Message length of the Reed-Solomon code.
        m : int
            Codeword size of the Reed-Solomon code.
        s : int
            Number of times to shorten the code.

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            A (((m-s) - 1) / ((t-s) + 1))-CFF((m-s)*(p^exp), (p^exp)^(t-s))
        """
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_short_reed_solomon(p, exp, k, m, s)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF from short Reed-Solomon code')
        result._cache_layout()
        return result

    @staticmethod
    def porat_rothschild(int p, int exp, int k, int r, int m) -> CFF:
        """
        Constructs a CFF using Porat and Rothschild's probabilistic linear error correcting code construction.

        Parameters
        ----------
        p : int
            The prime of the code's alphabet, q = p^exp.
        exp : int
            The power of the prime's alphabet q = p^exp.
        k : int
            The message length of the code.
        r : int
            The `d` of the desired CFF + 1 (so if you want a 3-CFF, r=4).
        m : int
            The codeword length of the code. Set to zero to calculate the best possible allowed by the theorem.

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            The newly constructed CFF
        """
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_porat_rothschild(p, exp, k, r, m)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF from Porat & Rothschild code')
        result._cache_layout()
        return result

    @staticmethod
    def extend_by_one(to_extend) -> CFF:
        """
        A recursive construction that constructs a new CFF from an existing CFF, where
        the new CFF has exactly one more row and column than the existing CFF

        Parameters
        ----------
        to_extend : CFF
            The CFF that is extended by one. This parameter is not modified, instead
            a new CFF is created and returned.

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            The newly constructed CFF
        """
        cdef CFF result = CFF.__new__(CFF)
        cdef CFF c_to_extend = to_extend
        result._c_cff = cff_extend_by_one(c_to_extend._c_cff)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF using extend by one construction')
        result._cache_layout()
        return result

    @staticmethod
    def double(to_double) -> CFF:
        """
        A recursive construction that returns a 2-CFF with double the amount of columns of a
        provided 2-CFF. This construction only works for d=2.

        Parameters
        ----------
        to_double : CFF
            The 2-CFF that is doubled. This parameter is not modified, instead
            a new CFF is created and returned.

        Raises
        ------
        MemoryError
            If CFF allocation failed
        ValueError
            If the to_double cff is not a 2-CFF

        Returns
        -------
        CFF
            The newly constructed CFF
        """
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
    def add(left, right) -> CFF:
        """
        A recursive construction that will make a new CFF from two existing CFFs
        with their `t` values added and their `n` values added together.

        Parameters
        ----------
        left : CFF
            The first CFF to add
        right : CFF
            The second CFF to add

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            The newly constructed CFF
        """
        cdef CFF result = CFF.__new__(CFF)
        cdef CFF c_left = left
        cdef CFF c_right = right
        result._c_cff = cff_additive(c_left._c_cff, c_right._c_cff)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF using additive construction')
        result._cache_layout()
        return result

    @staticmethod
    def kronecker(left, right) -> CFF:
        """
        A recursive construction that is the Kronecker product of two CFFs.

        Parameters
        ----------
        left : CFF
            The left operand to the Kronecker product
        right : CFF
            The right operand to the Kronecker product

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            The newly constructed CFF
        """
        cdef CFF result = CFF.__new__(CFF)
        cdef CFF c_left = left
        cdef CFF c_right = right
        result._c_cff = cff_kronecker(c_left._c_cff, c_right._c_cff)
        if result._c_cff == NULL:
            raise MemoryError('Failed to initialize CFF using Kronecker construction')
        result._cache_layout()
        return result

    @staticmethod
    def optimized_kronecker(outer, inner, bottom) -> CFF:
        """
        Constructs the optimized Kronecker product of 3 CFFs

        Parameters
        ----------

        Raises
        ------
        MemoryError
            If CFF allocation failed

        Returns
        -------
        CFF
            The newly constructed CFF
        """
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


cdef class ColsView:
    cdef CFF _cff

    def __cinit__(self, CFF cff):
        self._cff = cff

    def __len__(self) -> int:
        return self._cff._n

    def __getitem__(self, int c) -> tuple[int, ...]:
        cdef int r, bit_offset, byte_idx, bit_idx
        cdef int t = self._cff._t
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        if c < 0:
            c += self._cff._n

        if c < 0 or c >= self._cff._n:
            raise IndexError('Column index out of range')

        col = bytearray(t)
        for r in range(t):
            bit_offset = r * pitch + c
            byte_idx = bit_offset >> 3
            bit_idx = bit_offset & 7
            col[r] = (data[byte_idx] >> bit_idx) & 1

        return tuple(col)

    def __iter__(self) -> Iterator[tuple[int, ...]]:
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


cdef class RowsView:
    cdef CFF _cff

    def __cinit__(self, CFF cff):
        self._cff = cff

    def __len__(self) -> int:
        return self._cff._t

    def __getitem__(self, int r) -> tuple[int, ...]:
        cdef int c, bit_offset, byte_idx, bit_idx
        cdef int n = self._cff._n
        cdef int pitch = self._cff._row_pitch_bits
        cdef const unsigned char* data = self._cff._matrix

        if r < 0:
            r += self._cff._t

        if r < 0 or r >= self._cff._t:
            raise IndexError('Row index out of range')

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


cdef class PoolsView:
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
            raise IndexError('Pool index out of range')

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


cdef class SubsetsView:
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
            raise IndexError('Subset index out of range')

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
    """
    A class storing a "recipe book" of best-known constructions for CFFs of various sizes.

    The tables are not hardcoded, and are generated dynamically using a dynamic programming like algorithm.

    Precomputed tables can be found at https://matthewdemczyk.github.io/CFFtables/ .

    Examples
    --------

    Get a CFF with d=2, t= 15, and maximum known n:

    >>> #set n_max much larger than necessary (or consult precomputed tables to know exact values)
    >>> table = CFFTable(2,15,100000)
    >>> cff = table.get_by_t(2,15)
    >>> cff
    2-CFF(15,42)

    Get a CFF with d=3, n=25, and minimum known t:

    >>> #set t_max to n_max (or consult precomputed tables to know exact values)
    >>> table = CFFTable(3,25,25)
    >>> cff = table.get_by_n(3,25)
    >>> cff
    3-CFF(20,25)

    If you want a CFF but only know d and n, then you can set both t_max and n_max to the same
    value (n) in the constructor for this class. This approach will not work if you only know d and t, since n will
    usually be larger than t.

    If you want a CFF but only know d and t, then you should set n_max to a much much larger value than t.

    To know exact values, you can consult the precomputed tables.
    """
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
        '''
        The maximum d in the CFF tables

        Returns
        -------
        int
            The maximum d value permitted in the table
        '''
        return self._d_maximum

    @property
    def t_max(self):
        '''
        The maximum t permitted when constructing the CFF tables.

        Note: it's possible that CFFs with t = t_max do not appear in the tables if n_max was
        too small.

        For example if creating a table with CFFTable(3,1000000,25), the maximum t for d=3 is only 20.

        Returns
        -------
        int
            The maximum t value permitted in the table
        '''
        return self._t_maximum

    @property
    def n_max(self):
        '''
        The maximum n permitted when constructing the CFF tables.

        Note: it's possible that CFFs with n = n_max do not appear in the tables if t_max was
        too small.

        For example if creating a table with CFFTable(3,20,100000), the maximum n for d=3 is only 25.

        Returns
        -------
        int
            The maximum n value permitted in the table
        '''
        return self._n_maximum

    def get_by_t(self, int d, int t) -> CFF:
        """
        Construct a CFF from the tables  by providing the d and t parameters desired

        Parameters
        ----------
        d : int
            the d parameter of the desired cover-free family
        t : int
            the number of rows in the CFF's incidence matrix (the length of the CFF's ground set)

        Raises
        ------
        ValueError
            If the requested CFF is not present in the table
        MemoryError
            If allocating the CFF fails

        Returns
        -------
        CFF
            A CFF with the desired d and t, with maximum n from our constructions
        """
        if d > self.d_max or t > self.t_max or t < 1 or d < 1:
            raise ValueError(
            f'Invalid parameters: d must be in [1, {self.d_max}] and '
            f't must be in [1, {self.t_max}], got d={d}, t={t}')
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_table_get_by_t(self._c_cff_table_ctx, d, t)
        if result._c_cff == NULL:
            raise ValueError('CFF not in table, or memory allocation failed (cff_table_get_by_t returned NULL).'
                            'Try making a new table with larger n_max.')
        result._cache_layout()
        return result

    def get_by_n(self, int d, long long n, exact_n = True) -> CFF:
        """
        Construct a CFF using the tables by providing the d and n parameters desired

        If setting the exact_n parameter to False, this function will first determine the
        minimum number of t (number of rows) required for the specified d and n. Then, it
        will maximize n for the determined minimum t and specified d. In other words, if exact_n
        is set to False, this function will return a CFF with more columns, but still the same number
        of rows as the CFF with the requested n would've had.

        Parameters
        ----------
        d : int
            the d parameter of the desired cover-free family
        n : int
            The number of columns in the CFF's incidence matrix (the number of subset in its set system)
        exact_n : bool
            If False, returns a CFF with maximum n possible for the required t and d to get a CFF with the given n.
            If True, the CFF will have the exact n requested. This parameter is true by default.

        Raises
        ------
        ValueError
            If the requested CFF is not present in the table, or if memory allocation failed.

        Returns
        -------
        CFF
            A CFF with the desired t and n, possibly with n larger, and minimum t from our constructions, or None on failure
        """
        if d > self.d_max or n > self.n_max or n < 1 or d < 1:
            raise ValueError(
            f'Invalid parameters: d must be in [1, {self.d_max}] and '
            f'n must be in [1, {self.n_max}], got d={d}, n={n}')
        cdef CFF result = CFF.__new__(CFF)
        result._c_cff = cff_table_get_by_n(self._c_cff_table_ctx, d, n)
        if result._c_cff == NULL:
            raise ValueError('CFF not in table, or memory allocation failed (cff_table_get_by_n returned NULL).'
                            'Try making a new table with larger t_max.')
        if exact_n:
            result._reduce_cff_n(n)
        result._cache_layout()
        return result