from database import get_connection


print("Testing connection to PostgreSQL...")

connection = get_connection()

print("Successfully connected to PostgreSQL!")

connection.close()

print("Connection closed.")