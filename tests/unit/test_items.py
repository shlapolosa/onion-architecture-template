"""Unit tests for the Item vertical slice (in-memory adapters — no backing services)."""
from src.application.use_cases import CreateItem, GetItem, ListItems
from src.infrastructure.cache import NullCache
from src.infrastructure.repositories import InMemoryItemRepository


def _wired():
    repo, cache = InMemoryItemRepository(), NullCache()
    return CreateItem(repo, cache), GetItem(repo, cache), ListItems(repo)


def test_create_assigns_id():
    create, _, _ = _wired()
    item = create.execute(name="widget", description="a widget")
    assert item.id and item.name == "widget"


def test_get_roundtrip():
    create, get, _ = _wired()
    item = create.execute(name="widget")
    assert get.execute(item.id).name == "widget"


def test_get_missing_returns_none():
    _, get, _ = _wired()
    assert get.execute("nope") is None


def test_list_returns_all():
    create, _, list_items = _wired()
    create.execute(name="a"); create.execute(name="b")
    assert {i.name for i in list_items.execute()} == {"a", "b"}
