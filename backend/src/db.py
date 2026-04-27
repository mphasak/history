from psycopg_pool import AsyncConnectionPool
from psycopg.rows import dict_row

_pool: AsyncConnectionPool | None = None


async def init_pool(dsn: str) -> None:
    global _pool
    _pool = AsyncConnectionPool(
        dsn,
        kwargs={"row_factory": dict_row},
        open=False,
        min_size=1,
        max_size=10,
    )
    await _pool.open()


async def close_pool() -> None:
    if _pool:
        await _pool.close()


async def get_conn():
    """FastAPI dependency — yields a pooled connection."""
    async with _pool.connection() as conn:
        yield conn
