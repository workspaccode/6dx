package db

import (
	"context"
	"path/filepath"
	"testing"
)

// applyFile runs one embedded migration, the way Migrate does.
func applyFile(t *testing.T, database *DB, name string) {
	t.Helper()
	body, err := sqliteMigrations.ReadFile("migrations/sqlite/" + name)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := database.ExecContext(context.Background(), string(body)); err != nil {
		t.Fatalf("%s: %v", name, err)
	}
}

// 0003 must move an existing workspace into a default group without losing
// a member, a project or a pending invite.
func TestGroupsMigrationBackfillsExistingWorkspaces(t *testing.T) {
	ctx := context.Background()
	database, err := Open(ctx, filepath.Join(t.TempDir(), "m.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer database.Close()
	applyFile(t, database, "0001_init.sql")
	applyFile(t, database, "0002_security.sql")

	seed := []string{
		`insert into users (uid, created_at, updated_at) values
		   ('o','t','t'), ('a','t','t'), ('d','t','t'), ('r','t','t'), ('v','t','t')`,
		`insert into workspaces (id, name, slug, owner_uid, created_at, updated_at)
		   values ('w1', 'Old WS', 'old', 'o', 't', 't')`,
		`insert into workspace_members (workspace_id, user_uid, role, created_at) values
		   ('w1','o','owner','t'), ('w1','a','admin','t'), ('w1','d','developer','t'),
		   ('w1','r','reviewer','t'), ('w1','v','viewer','t')`,
		`insert into projects (id, workspace_id, name, created_at, updated_at)
		   values ('p1', 'w1', 'Proj', 't', 't')`,
		`insert into workspace_invites (id, workspace_id, email, role, status, sent_at, expires_at)
		   values ('i1', 'w1', 'x@y.z', 'viewer', 'pending', 't', 'z')`,
	}
	for _, q := range seed {
		if _, err := database.ExecContext(ctx, q); err != nil {
			t.Fatalf("seed: %v\n%s", err, q)
		}
	}

	applyFile(t, database, "0003_groups.sql")

	var groupID, groupType string
	var isDefault int
	if err := database.QueryRowContext(ctx,
		`select id, type, is_default from groups where workspace_id = 'w1'`,
	).Scan(&groupID, &groupType, &isDefault); err != nil {
		t.Fatal(err)
	}
	if groupType != "software" || isDefault != 1 {
		t.Fatalf("default group: %s %d", groupType, isDefault)
	}

	want := map[string][2]string{
		"o": {"lead", "tech_lead"}, "a": {"admin", "tech_lead"}, "d": {"member", "developer"},
		"r": {"member", "reviewer"}, "v": {"guest", "client"},
	}
	for uid, roles := range want {
		var groupRole, functional string
		if err := database.QueryRowContext(ctx,
			`select group_role, functional_role from group_members where group_id = ? and user_uid = ?`,
			groupID, uid).Scan(&groupRole, &functional); err != nil {
			t.Fatalf("%s: %v", uid, err)
		}
		if groupRole != roles[0] || functional != roles[1] {
			t.Errorf("%s = %s/%s, want %s/%s", uid, groupRole, functional, roles[0], roles[1])
		}
	}

	var projectGroup, inviteGroup, inviteRole string
	_ = database.QueryRowContext(ctx, `select group_id from projects where id = 'p1'`).Scan(&projectGroup)
	_ = database.QueryRowContext(ctx,
		`select group_id, group_role from workspace_invites where id = 'i1'`).Scan(&inviteGroup, &inviteRole)
	if projectGroup != groupID || inviteGroup != groupID || inviteRole != "guest" {
		t.Errorf("project group %q, invite group %q role %q", projectGroup, inviteGroup, inviteRole)
	}

	var plan string
	_ = database.QueryRowContext(ctx, `select plan_id from workspaces where id = 'w1'`).Scan(&plan)
	if plan != "free" {
		t.Errorf("plan = %q, want free", plan)
	}
}
