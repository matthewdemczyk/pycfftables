import pytest
from pycfftables import CFF, CFFTable

def test_all_zeros():
    cff = CFF.all_zeros(2,10,15)
    assert cff
    assert cff.d == 2
    assert cff.t == 10
    assert cff.n == 15
    print(cff)

def test_identity():
    cff = CFF.identity(2,40)
    assert cff
    assert cff.verify()
    print(cff)

    cff = CFF.identity(2,20)
    assert cff
    assert cff.verify()
    print(cff)

def test_sperner():
    cff = CFF.sperner(10)
    assert cff
    assert cff.verify()
    print(cff)

    cff = CFF.sperner(20)
    assert cff
    assert cff.verify()
    print(cff)

def test_sts():
    cff = CFF.sts(9)
    assert cff
    assert cff.verify()
    print(cff)

    cff = cff.sts(13)
    assert cff
    assert cff.verify()
    print(cff)