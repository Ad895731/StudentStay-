from sqlalchemy import text
from app.core.database import engine


def test_database_connection():
    """Verify that the application can connect to the PostgreSQL database."""
    with engine.connect() as connection:
        result = connection.execute(text("SELECT 1")).scalar()
        assert result == 1
