import pytest
from pycfftables import CFF, CFFTable

def test_get_by_t():
    table = CFFTable(2, 100, 1000)
    assert table.d_max == 2
    assert table.t_max == 100
    assert table.n_max == 1000
    cff = table.get_by_t(2, 15)
    assert cff
    assert cff.d == 2
    assert cff.t == 15
    assert cff.verify()

def test_get_by_n():
    table = CFFTable(3, 200, 50000)
    cff = table.get_by_n(3, 25)
    assert cff
    assert cff.d == 3
    assert cff.n == 25
    assert cff.verify()

def test_get_by_n_non_exact():
    table = CFFTable(3, 200, 50000)
    cff = table.get_by_n(3, 24, False)
    assert cff
    assert cff.d == 3
    assert cff.n == 25
    assert cff.verify()