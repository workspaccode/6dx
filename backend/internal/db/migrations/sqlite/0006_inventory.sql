-- 0006: procurement and inventory (hardware only) — docs/design/groups-and-roles.md §7.5.
--
-- Group level (shared by the group's projects): vendors, stock movements,
-- the PO approval threshold. The same part number in two projects is the
-- same reel on the shelf, so stock is keyed by part number, not part id.
--
-- Project level: purchase orders and reservations of stock for a build.
--
-- Stock on hand is the sum of the movements, which are append-only: a
-- correction is a new 'adjust' movement. Money is integer cents.

create table inv_settings (
  group_id                   text primary key references groups (id) on delete cascade,
  -- A PO at or above this total waits for po.approve; 0 = every PO does.
  po_approval_threshold_cents integer not null default 0 check (po_approval_threshold_cents >= 0),
  currency                   text not null default 'USD' check (length(currency) = 3),
  updated_at                 text not null default ''
);

create table inv_vendors (
  id                text primary key,
  group_id          text not null references groups (id) on delete cascade,
  name              text not null check (length(name) between 1 and 80),
  contact           text check (contact is null or length(contact) <= 500),
  default_lead_days integer not null default 14 check (default_lead_days between 0 and 365),
  archived          integer not null default 0,
  created_at        text not null
);
create unique index inv_vendors_name_idx on inv_vendors (group_id, lower(name));

create table inv_movements (
  id          text primary key,
  group_id    text not null references groups (id) on delete cascade,
  part_number text not null check (length(part_number) between 1 and 64),
  location    text not null default 'main' check (length(location) between 1 and 40),
  qty         integer not null check (qty <> 0 and qty between -1000000 and 1000000),
  kind        text not null check (kind in ('receive', 'issue', 'adjust', 'transfer')),
  project_id  text references projects (id) on delete set null,
  build_id    text references hw_builds (id) on delete set null,
  po_id       text,
  note        text check (note is null or length(note) <= 500),
  by_uid      text references users (uid) on delete set null,
  at          text not null
);
create index inv_movements_stock_idx on inv_movements (group_id, part_number, location);

-- Append-only: history is never rewritten. Only the foreign keys' own
-- "set null" (a deleted project, build or user) may touch a row: SQLite runs
-- that as an UPDATE, so the trigger lets through updates that change
-- nothing but those three columns to null.
create trigger inv_movements_no_update before update on inv_movements
when new.id is not old.id or new.group_id is not old.group_id
  or new.part_number is not old.part_number or new.location is not old.location
  or new.qty is not old.qty or new.kind is not old.kind or new.po_id is not old.po_id
  or new.note is not old.note or new.at is not old.at
  or (new.project_id is not old.project_id and new.project_id is not null)
  or (new.build_id is not old.build_id and new.build_id is not null)
  or (new.by_uid is not old.by_uid and new.by_uid is not null)
begin select raise(abort, 'movements_are_append_only'); end;
create trigger inv_movements_no_delete before delete on inv_movements
when exists (select 1 from groups where id = old.group_id)
begin select raise(abort, 'movements_are_append_only'); end;

create table inv_pos (
  id           text primary key,
  project_id   text not null references projects (id) on delete cascade,
  vendor_id    text not null references inv_vendors (id) on delete restrict,
  number       integer not null,
  build_id     text references hw_builds (id) on delete set null,
  status       text not null default 'draft'
               check (status in ('draft', 'pending_approval', 'ordered', 'partially_received',
                                 'received', 'closed', 'cancelled')),
  currency     text not null default 'USD',
  note         text check (note is null or length(note) <= 2000),
  created_by   text references users (uid) on delete set null,
  submitted_by text references users (uid) on delete set null,
  approved_by  text references users (uid) on delete set null,
  ordered_at   text,
  expected_at  text,
  created_at   text not null,
  updated_at   text not null,
  unique (project_id, number)
);

create table inv_po_lines (
  po_id           text not null references inv_pos (id) on delete cascade,
  part_number     text not null check (length(part_number) between 1 and 64),
  qty             integer not null check (qty between 1 and 1000000),
  unit_cost_cents integer not null default 0 check (unit_cost_cents >= 0),
  received_qty    integer not null default 0 check (received_qty >= 0 and received_qty <= qty),
  primary key (po_id, part_number)
);

create table inv_reservations (
  id          text primary key,
  project_id  text not null references projects (id) on delete cascade,
  build_id    text references hw_builds (id) on delete cascade,
  part_number text not null check (length(part_number) between 1 and 64),
  qty         integer not null check (qty between 1 and 1000000),
  status      text not null default 'active' check (status in ('active', 'issued', 'released')),
  po_id       text,
  created_by  text references users (uid) on delete set null,
  created_at  text not null,
  updated_at  text not null
);
create index inv_reservations_part_idx on inv_reservations (part_number, status);
create index inv_reservations_build_idx on inv_reservations (build_id, status);
