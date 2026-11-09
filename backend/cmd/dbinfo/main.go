// Command dbinfo prints what the SQLite file contains ? a quick sanity check
// after a migration without needing a sqlite3 binary.
package main

import (
	"context"
	"fmt"
	"os"

	"github.com/workspaccode/6dx/backend/internal/db"
)

func main() {
	path := os.Getenv("DATABASE_FILE")
	if path == "" {
		path = "6dx.db"
	}
	d, err := db.Open(context.Background(), path)
	if err != nil {
		panic(err)
	}
	defer d.Close()

	rows, err := d.QueryContext(context.Background(), `
		select name from sqlite_master
		where type = 'table' and name not like 'sqlite_%'
		order by name`)
	if err != nil {
		panic(err)
	}
	defer rows.Close()

	count := 0
	for rows.Next() {
		var name string
		_ = rows.Scan(&name)
		fmt.Println(" -", name)
		count++
	}

	var indexes int
	if err := d.QueryRowContext(context.Background(), `
		select count(*) from sqlite_master
		where type = 'index' and name not like 'sqlite_%'`).Scan(&indexes); err != nil {
		panic(err)
	}
	fmt.Printf("tables: %d, indexes: %d\n", count, indexes)
}
