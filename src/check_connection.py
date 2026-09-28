import os

from dotenv import load_dotenv
from sqlalchemy import URL, create_engine, text


def get_engine():
    load_dotenv()
    url = URL.create(
        "postgresql+psycopg2",
        username=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        database=os.getenv("DB_NAME"),
    )
    return create_engine(url)


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
