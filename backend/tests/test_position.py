from app.utils.position import POSITION_GAP, next_position, position_between


def test_next_position_empty_column():
    assert next_position(None) == POSITION_GAP


def test_next_position_appends_after_max():
    assert next_position(100.0) == 100.0 + POSITION_GAP


def test_position_between_empty_column():
    assert position_between(None, None) == POSITION_GAP


def test_position_between_start():
    assert position_between(None, 10.0) == 5.0


def test_position_between_end():
    assert position_between(10.0, None) == 10.0 + POSITION_GAP


def test_position_between_two_cards():
    assert position_between(10.0, 20.0) == 15.0
