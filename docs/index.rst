pycfftables Documentation
=========================

Python wrapper for libcfftables - cover-free family construction and manipulation.

A cover-free family, denoted `d-CFF(t,n)` is a set system where the ground set has `t` elements,
the set system contains `n` subsets, and no subset is contained in the union
of any `d` other subsets. When a `d`-cover-free family is viewed as an incidence matrix it is
also known as a  `d`-disjunct matrix. For more information
see https://en.wikipedia.org/wiki/Disjunct_matrix .

The main feature of this library is the ability to provide a `(d,n)` and construct a CFF that minimizes
`t`, or provide a `(d,t)` and construct a CFF that maximizes `n` from our selection of CFF constructions.

The tables that this library will generate are available at https://matthewdemczyk.github.io/CFFtables/
for values up to n=100 trillion and d=25. This library can generate larger values though.

Quick Start
-----------

An example of using a CFF for group testing:

.. code-block:: python

   from pycfftables import CFFTable

   group_test_calls = 0
   def group_test(list_of_elements):
      """
      Example group testing function. A real application would somehow combine
      elements into tests rather than directly reading element values as done here.
      """
      global group_test_calls
      group_test_calls += 1
      return any(list_of_elements)

   # Elements to test (True = positive)
   elements = [False] * 12
   elements[0] = True
   elements[9] = True

   # Construct a CFF for group testing
   table = CFFTable(2,100,10000) # consult pre-computed table to know exact values to use here
   cff = table.get_by_n(2, len(elements)) # d=2 because we assume at most 2 elements are positive

   # Test each pool - eliminate indices that are proven negative
   suspects = set(range(len(elements)))
   for test in cff.pools:
      test_result = group_test([elements[i] for i in test])
      if not test_result:
         suspects -= set(test)

   print(f'Positives at indices {suspects}.')
   print(f'Found using {group_test_calls} tests out of {len(elements)} elements.')

Installation
------------

Dependencies
~~~~~~~~~~~~

**Ubuntu/Debian:**

.. code-block:: bash

   sudo apt install libflint-dev cmake

**macOS:**

.. code-block:: bash

   brew install flint cmake

Alternatively, flint and cmake can be installed from conda-forge on both macOS and Linux:

.. code-block:: bash

   conda install -c conda-forge libflint cmake make

Libraries
~~~~~~~~~

.. code-block:: bash

   # Clone and build libcfftables
   git clone https://github.com/matthewdemczyk/libcfftables.git
   cd libcfftables && mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release && cmake --build . && sudo cmake --install .
   sudo ldconfig  # Linux only, skip on macOS
   cd ../..

   # Clone and install pycfftables
   git clone https://github.com/matthewdemczyk/pycfftables.git
   cd pycfftables && pip install .

API Reference
-------------

.. toctree::
   :maxdepth: 2

   api

Index
==================

* :ref:`genindex`