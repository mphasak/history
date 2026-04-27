import os
import pytest
import psycopg
from psycopg.rows import dict_row

DSN = os.environ.get(
    "DATABASE_URL",
    "postgresql://history_sim:dev@localhost:5432/history_sim",
)


@pytest.fixture(scope="session")
def db_conn():
    """Synchronous connection for session-scoped setup checks."""
    try:
        conn = psycopg.connect(DSN, row_factory=dict_row)
        yield conn
        conn.close()
    except Exception as e:
        pytest.skip(f"Database not available: {e}")


@pytest.fixture
async def aconn():
    """Async connection for resolver tests."""
    try:
        conn = await psycopg.AsyncConnection.connect(DSN, row_factory=dict_row)
        yield conn
        await conn.close()
    except Exception as e:
        pytest.skip(f"Database not available: {e}")
