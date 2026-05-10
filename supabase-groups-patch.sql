-- =========================================================
-- FIGUS2026 - parche seguro para grupos privados
-- Ejecutar en Supabase > SQL Editor.
-- No borra figuritas ni datos existentes.
-- =========================================================

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique,
  created_by uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.group_members (
  group_id uuid references public.groups(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz default now(),
  primary key (group_id, user_id)
);

create index if not exists groups_invite_code_idx on public.groups(invite_code);
create index if not exists group_members_user_idx on public.group_members(user_id);
create index if not exists group_members_group_idx on public.group_members(group_id);

alter table public.groups enable row level security;
alter table public.group_members enable row level security;

drop policy if exists groups_read_member on public.groups;
create policy groups_read_member on public.groups for select
  using (exists (
    select 1
    from public.group_members gm
    where gm.group_id = id and gm.user_id = auth.uid()
  ));

drop policy if exists groups_insert_owner on public.groups;
create policy groups_insert_owner on public.groups for insert
  with check (created_by = auth.uid());

drop policy if exists groups_update_owner on public.groups;
create policy groups_update_owner on public.groups for update
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

drop policy if exists group_members_read_own on public.group_members;
create policy group_members_read_own on public.group_members for select
  using (user_id = auth.uid());

drop policy if exists group_members_insert_self on public.group_members;
create policy group_members_insert_self on public.group_members for insert
  with check (user_id = auth.uid());

drop policy if exists group_members_delete_self on public.group_members;
create policy group_members_delete_self on public.group_members for delete
  using (user_id = auth.uid());

create or replace function public.create_closed_group(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_code text;
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'group name is required';
  end if;

  insert into public.profiles (id, display_name)
  values (v_user, 'Usuario')
  on conflict (id) do nothing;

  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    begin
      insert into public.groups (name, invite_code, created_by)
      values (nullif(trim(p_name), ''), v_code, v_user)
      returning id into v_group_id;
      exit;
    exception when unique_violation then
      null;
    end;
  end loop;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_user, 'owner')
  on conflict do nothing;

  return v_group_id;
end
$$;

create or replace function public.join_closed_group(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  insert into public.profiles (id, display_name)
  values (v_user, 'Usuario')
  on conflict (id) do nothing;

  select id into v_group_id
  from public.groups
  where invite_code = regexp_replace(upper(coalesce(p_invite_code, '')), '[^A-Z0-9]', '', 'g');

  if v_group_id is null then
    raise exception 'group not found';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_user, 'member')
  on conflict do nothing;

  return v_group_id;
end
$$;
