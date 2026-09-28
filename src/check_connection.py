import os

from sqlalchemy import text

from db import get_engine


def main():
    try:
        with get_engine().connect() as conn:
            conn.execute(text("SELECT 1"))
        print("connected")
    except Exception as e:
        # driver errors can echo connection details, so mask the password just in case
        message = str(getattr(e, "orig", None) or e)
        password = os.getenv("DB_PASSWORD")
        if password:
            message = message.replace(password, "****")
        print(f"error: {message}")


if __name__ == "__main__":
    main()
