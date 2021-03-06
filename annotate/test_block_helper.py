import pytest
import pandas as pd
import block_helper as bh

chr_ref = pd.DataFrame({'start': [100, 300, 410],
                        'end': [200, 400, 450]})
MIN_CLIP = 30

@pytest.mark.parametrize('coord,expected', [((150, 160), False),
                                            ((90, 130), False),
                                            ((70, 130), True),
                                            ((190, 220), False),
                                            ((190, 230), True),
                                            ((90, 210), True),
                                            ((170, 320), True),
                                            ((350, 420), False)])
def test_is_novel_block(coord, expected):
    assert bh.is_novel_block(coord, chr_ref, MIN_CLIP) == expected
