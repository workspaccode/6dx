-- 0009: certifications and lab booking (hardware) — docs/design/groups-and-roles.md §7.2.
--
-- Certifications are per project: a standard (FCC, CE, UL…) tested on a
-- released BOM revision at a lab, with the dates that drive the plan (labs
-- book weeks ahead, certification takes 2 to 12 weeks). Lab equipment is
-- shared by the group's projects and booked by time slot; two active
-- bookings of one asset never overlap (checked by the API in one
-- transaction). Times are UTC, stored as "2006-01-02T15:04:05Z" so string
-- order is time order.

create table hw_certs (
  id                 text primary key,
  project_id         text not null references projects (id) on delete cascade,
  standard           text not null check (length(standard) between 1 and 40),
  region             text check (region is null or length(region) <= 40),
  lab                text check (lab is null or length(lab) <= 80),
  bom_rev_id         text references hw_bom_revs (id) on delete set null,
  status             text not null default 'planned'
                     check (status in ('planned', 'booked', 'testing', 'passed', 'failed', 'expired')),
  planned_at         text,
  due_at             text,
  certified_at       text,
  expires_at         text,
  certificate_number text check (certificate_number is null or length(certificate_number) <= 80),
  note               text check (note is null or length(note) <= 2000),
  created_by         text references users (uid) on delete set null,
  created_at         text not null,
  updated_at         text not null
);
create index hw_certs_project_idx on hw_certs (project_id, status);

create table lab_assets (
  id         text primary key,
  group_id   text not null references groups (id) on delete cascade,
  name       text not null check (length(name) between 1 and 80),
  kind       text check (kind is null or length(kind) <= 40),
  location   text check (location is null or length(location) <= 80),
  archived   integer not null default 0,
  created_at text not null
);
create unique index lab_assets_name_idx on lab_assets (group_id, lower(name));

create table lab_bookings (
  id         text primary key,
  asset_id   text not null references lab_assets (id) on delete cascade,
  project_id text references projects (id) on delete set null,
  user_uid   text references users (uid) on delete set null,
  starts_at  text not null,
  ends_at    text not null,
  purpose    text check (purpose is null or length(purpose) <= 200),
  status     text not null default 'active' check (status in ('active', 'cancelled')),
  created_at text not null,
  check (ends_at > starts_at)
);
create index lab_bookings_asset_idx on lab_bookings (asset_id, status, starts_at);
