import pytest
from pycfftables import CFF, CFFTable

def test_views_len():
    cff = CFF.sts(13)
    assert len(cff.rows) == 13
    assert len(cff.cols) == 26
    assert len(cff.pools) == 13
    assert len(cff.subsets) == 26

def test_rows_pools():
    cff = CFF.sts(13)
    for i in range(len(cff.rows)):
        assert len(cff.pools[i]) == sum(cff.rows[i])

def test_cols_subsets():
    cff = CFF.sts(13)
    for i in range(len(cff.cols)):
        assert len(cff.subsets[i]) == sum(cff.cols[i])