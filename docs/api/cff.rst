CFF Class
=========

.. currentmodule:: pycfftables

.. autoclass:: CFF
   :undoc-members:
   :show-inheritance:
   :special-members: __getitem__, __setitem__, __repr__, __str__


Reading a CFF
-------------

CFF objects have 4 views available by accessing either the ``CFF.rows``,
``CFF.cols``, ``CFF.subsets``, ``CFF.pools`` properties, then iterating over them or indexing them.
All of these views will return a tuple (when indexing) or yield a tuple (when iterating).

An example of reading the group testing pools of a CFF:

.. code-block:: python

   table = CFFTable(d_max = 5, t_max = 100, n_max = 10000)
   cff = table.get_by_t(d = 2, t = 15)
   for pool in cff.pools:
      # ... your group testing application code here...
      # there are t pools with values in 0 ... n-1, given as tuples by CFF.pools
      print(pool)

Indexing
--------

CFF objects support 2D indexing with ``[row, col]`` syntax:

.. code-block:: python

   cff = CFF.sperner(6)
   value = cff[0, 0]  # Get value at row 0, col 0
   cff[0, 0] = 1      # Set value



Construction Methods
--------------------

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

Matrix Operations
-----------------

.. automethod:: CFF.get_value
.. automethod:: CFF.set_value
.. automethod:: CFF.verify

File I/O
--------

.. automethod:: CFF.write_to_filepath
.. automethod:: CFF.write_to_file_obj

Other Methods
-------------

.. automethod:: CFF.copy