from fastapi import APIRouter, Depends
from psycopg import AsyncConnection

from .db import get_conn
from .models import Perspective

router = APIRouter()


@router.get("/perspectives", response_model=list[Perspective])
async def list_perspectives(
    show_deprecated: bool = False,
    conn: AsyncConnection = Depends(get_conn),
) -> list[Perspective]:
    """List all admitted (and optionally retired/rejected) perspectives."""
    # Cast domain_scope to text[] so psycopg3 decodes the custom enum array correctly.
    sql = """
        SELECT id, display_name, domain_scope::text[] AS domain_scope,
               summary, proponents, methodology_notes,
               parent_perspective_id, default_active, status
        FROM perspective
        {where}
        ORDER BY display_name
    """
    if show_deprecated:
        rows = await conn.execute(sql.format(where=""))
    else:
        rows = await conn.execute(
            sql.format(where="WHERE status NOT IN ('rejected', 'retired')")
        )
    result = []
    async for r in rows:
        r = dict(r)
        r["domain_scope"] = list(r.get("domain_scope") or [])
        result.append(Perspective(**r))
    return result
