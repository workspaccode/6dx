-- 0008: multi-level BOM — a part with children is an assembly (its own
-- sub-BOM). A BOM revision lists top-level parts; the tree under each
-- assembly comes from hw_part_children, exploded by the API (depth ≤ 10).
--
-- A released BOM revision must stay a fixed snapshot, so an assembly's
-- children change only while the assembly is not in any released revision
-- (directly or inside another assembly) and is not in production: a
-- changed structure is a new revision of the assembly. The API enforces
-- this (it needs the recursive check) and refuses cycles.

create table hw_part_children (
  parent_part_id  text not null references hw_parts (id) on delete cascade,
  child_part_id   text not null references hw_parts (id) on delete restrict,
  quantity        integer not null check (quantity between 1 and 100000),
  ref_designators text check (ref_designators is null or length(ref_designators) <= 500),
  primary key (parent_part_id, child_part_id),
  check (parent_part_id <> child_part_id)
);
create index hw_part_children_child_idx on hw_part_children (child_part_id);
