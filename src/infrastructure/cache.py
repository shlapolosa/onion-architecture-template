"""Infrastructure: cache adapter from the platform binding contract.

REDIS_URL/CACHE_URL arrive via envFrom "<cache-component>-conn" when the OAM
webservice sets `cache: <component-name>`. Falls back to a no-op cache when
unbound — the service runs identically without a cache component.
"""
from typing import Optional

from ..domain.repositories import Cache
from .config import Settings


class NullCache(Cache):
    def get(self, key: str) -> Optional[str]:
        return None

    def set(self, key: str, value: str, ttl_seconds: int = 300) -> None:
        return None

    def delete(self, key: str) -> None:
        return None


class RedisCache(Cache):
    def __init__(self, url: str):
        import redis  # lazy: only needed when a cache is actually bound
        self._r = redis.Redis.from_url(url, socket_timeout=2, socket_connect_timeout=2)

    def get(self, key: str) -> Optional[str]:
        try:
            v = self._r.get(key)
            return v.decode() if v is not None else None
        except Exception:
            return None  # cache-aside: failures degrade to a miss, never an error

    def set(self, key: str, value: str, ttl_seconds: int = 300) -> None:
        try:
            self._r.setex(key, ttl_seconds, value)
        except Exception:
            pass

    def delete(self, key: str) -> None:
        try:
            self._r.delete(key)
        except Exception:
            pass


def get_cache(settings: Settings) -> Cache:
    url = settings.redis_url
    if url:
        try:
            return RedisCache(url)
        except Exception:
            return NullCache()
    return NullCache()
