import sqlite3
import sys


path = sys.argv[1]
connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
print("file rows:", connection.execute("SELECT COUNT(*) FROM files").fetchone()[0])
print("categories:")
for row in connection.execute(
    "SELECT category, COUNT(*), SUM(size), MIN(size), MAX(size) "
    "FROM files GROUP BY category ORDER BY category"
):
    print(row)
print("largest rows:")
for row in connection.execute(
    "SELECT hex(id), size, length(content), category, atime FROM files "
    "ORDER BY size DESC LIMIT 40"
):
    print(row)
for name, sql in connection.execute(
    "SELECT name, sql FROM sqlite_master WHERE type = 'table' ORDER BY name"
):
    print(name)
    print(sql)
