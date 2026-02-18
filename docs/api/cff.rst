CFF Class
=========

.. currentmodule:: pycfftables

.. autoclass:: CFF
   :undoc-members:
   :special-members: __repr__, __str__


Reading a CFF
-------------

CFF objects provide four views for accessing the incidence matrix in different ways:

   - ``CFF.rows`` — each element is a tuple of n integers (0s and 1s), one per row
   - ``CFF.cols`` — each element is a tuple of t integers (0s and 1s), one per column
   - ``CFF.subsets`` — each element is a tuple of row indices where the column contains a 1, one per column
   - ``CFF.pools`` — each element is a tuple of column indices where the row contains a 1, one per row

All views support indexing and iteration. Indexing returns a single tuple, iteration produces one tuple per element.

.. autoattribute:: CFF.rows
.. autoattribute:: CFF.cols
.. autoattribute:: CFF.subsets
.. autoattribute:: CFF.pools
.. automethod:: CFF.__getitem__
.. automethod:: CFF.__setitem__

Properties
----------

.. autoattribute:: CFF.d
.. autoattribute:: CFF.t
.. autoattribute:: CFF.n
.. autoattribute:: CFF.shape


Direct Constructions
--------------------

.. automethod:: CFF.all_zeros
.. automethod:: CFF.identity
.. automethod:: CFF.sperner
.. automethod:: CFF.sts
.. automethod:: CFF.reed_solomon
.. automethod:: CFF.short_reed_solomon
.. automethod:: CFF.porat_rothschild

Recursive Constructions
------------------------

.. automethod:: CFF.extend_by_one
.. automethod:: CFF.add
.. automethod:: CFF.double
.. automethod:: CFF.kronecker
.. automethod:: CFF.optimized_kronecker

Other Methods
-------------

.. automethod:: CFF.verify
.. automethod:: CFF.copy
.. automethod:: CFF.write_to_filepath