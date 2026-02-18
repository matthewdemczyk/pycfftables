[![Documentation](https://img.shields.io/badge/docs-doxygen-blue.svg)](https://pycfftables.readthedocs.io/en/latest/index.html)
![CI](https://github.com/matthewdemczyk/pycfftables/actions/workflows/CI.yaml/badge.svg)

## About

This is a python wrapper for the C library libcfftables. This library constructs $d$-Cover-Free Families (CFFs).

A $d$-CFF($t,n$) is a set system where the ground set has $t$ elements, the set system has $n$ subsets, and no subset is contained in the union of any other $d$ subsets.

It's generally desirable to maximize the number of subsets for a given ground set while maintaining the cover-free property. This library selects the best available CFF construction implemented in the library to do so. "Best" here means maximizing $n$ for fixed $(d,t)$, or minimizing $t$ for fixed $(d,n)$, based on known constructions.

This library stores cover-free families as $0-1$ incidence matrices, using a bitfield. When a $d$-cover-free family is viewed as an incidence matrix it is equivalent to a $d$-disjunct matrix.

## Basic usage
The main feature of this library is the ability to provide a $(d,n)$ and construct a CFF that minimizes $t$, or provide a $(d,t)$ and construct a CFF that maximizes $n$ from our selection of CFF constructions.

Usage:
* Initialize the CFF tables up to some maximum values, and construct a CFF from these tables
* Read the CFF, for use in your application

Basic example of using a CFF with group testing:

```python
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
```

## Tables of CFFs used

The tables that the library will generate and use are available here: https://matthewdemczyk.github.io/CFFtables/

These precomputed tables go up to $n=100$ trillion and $d=25$. The library can generate tables for larger values. The tables are not hardcoded and are generated dynamically up to the arguments provided to `cff_table_create()`.

## Documentation

Full API documentation is available at: https://pycfftables.readthedocs.io/en/latest/index.html

## Installation
```bash
# Install dependencies (Ubuntu/Debian)
sudo apt install libflint-dev cmake

# Clone and build libcfftables
git clone https://github.com/matthewdemczyk/libcfftables.git
cd libcfftables && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release && cmake --build . && sudo cmake --install .
cd ../..

# Clone and install pycfftables
git clone https://github.com/matthewdemczyk/pycfftables.git
cd pycfftables && pip install .
```

## Uninstalling
To uninstall, manually remove the installed files from libcfftables, and use pip to uninstall pycfftables:
```bash
sudo rm -rf /usr/local/include/libcfftables
sudo rm -f /usr/local/lib/libcfftables.so*
sudo rm -rf /usr/local/lib/cmake/libcfftables
sudo rm -f /usr/local/lib/pkgconfig/libcfftables.pc

pip uninstall pycfftables
```

## Licensing

This project is licensed under the MIT License.

It links against FLINT, which is licensed under the GNU Lesser General Public License v3.