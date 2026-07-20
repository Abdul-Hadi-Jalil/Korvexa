from app.utils.keygen import derive_project_key, unique_project_key


def test_derive_key_single_word():
    assert derive_project_key("Marketing") == "MARK"


def test_derive_key_short_word_padded():
    assert derive_project_key("Ab") == "AB"


def test_derive_key_multi_word_uses_initials():
    assert derive_project_key("Marketing Site Revamp") == "MSR"


def test_derive_key_strips_punctuation():
    # Apostrophes split words ("Acme's" -> "Acme" + "s"); initials are taken
    # from whatever alphanumeric words remain.
    assert derive_project_key("Acme's Big Launch!") == "ASBL"


def test_derive_key_empty_name_falls_back():
    assert derive_project_key("!!!") == "PROJ"


def test_unique_key_no_collision():
    assert unique_project_key("ACME", set()) == "ACME"


def test_unique_key_appends_suffix_on_collision():
    result = unique_project_key("ACME", {"ACME"})
    assert result == "ACME2"


def test_unique_key_finds_next_free_suffix():
    result = unique_project_key("ACME", {"ACME", "ACME2", "ACME3"})
    assert result == "ACME4"
