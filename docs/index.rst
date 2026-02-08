pycfftables Documentation
=========================

Python wrapper for libcfftables - Cover-Free Family construction and manipulation.

A cover-free family (d-CFF) is a set system where no subset is contained in the 
union of any d other subsets.

Quick Start
-----------

.. code-block:: python

   from pycfftables import CFF, CFFTable

   # Create a CFF from Sperner system
   cff = CFF.sperner(6)
   print(cff)  # 1-CFF(4,6)

   # Access matrix elements
   value = cff[0, 0]  # Get element at row 0, col 0
   cff[0, 0] = 1      # Set element

   # Use the tables for optimal CFFs
   table = CFFTable(d_max=3, t_max=100, n_max=2000)
   cff = table.get_by_t(d=3, t=20)  # Get 3-CFF with t=20

Installation
------------

From conda-forge::

   conda install pycfftables

From PyPI::

   pip install pycfftables

API Reference
-------------

.. toctree::
   :maxdepth: 2

   api

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`