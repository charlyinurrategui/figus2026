
create index if not exists profiles_zone_idx on public.profiles(zone);
create index if not exists profiles_city_idx on public.profiles(city);

-- 2) STICKERS (catálogo de las 980 figuritas)
-- 2) STICKERS (catálogo de las 993 figuritas)
create table if not exists public.stickers (
  id text primary key,            -- ej: ARG-012, FWC-001, CC-003
  album text not null default 'WC2026',

create index if not exists msg_recipient_idx on public.messages(recipient_id, created_at desc);

-- 5) GROUPS (grupos cerrados de intercambio)
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

-- =========================================================
-- VISTAS DERIVADAS
-- =========================================================
  they_give_me int,
  i_give_them int,
  score int
) language sql stable as $$
) language sql stable security definer
set search_path = public
as $$
  with
    my_missing as (select sticker_id from public.v_user_missing where user_id = p_user),
    my_avail   as (select sticker_id from public.v_user_available where user_id = p_user),
    -- otros usuarios con visibility public
    others as (
      select id from public.profiles
      where id <> p_user and visibility = 'public'
      where auth.uid() = p_user and id <> p_user and visibility = 'public'
    ),
    -- ellos me dan = lo que está en sus disponibles y me falta
    they_give as (
  order by score desc;
$$;

-- Matching limitado a integrantes de un grupo cerrado.
create or replace function public.f_group_matches(p_user uuid, p_group uuid)
returns table (
  other_user uuid,
  display_name text,
  zone text,
  city text,
  country text,
  whatsapp text,
  they_give_me int,
  i_give_them int,
  score int,
  group_name text
) language sql stable security definer
set search_path = public
as $$
  with
    authorized as (
      select auth.uid() = p_user and exists (
        select 1 from public.group_members
        where group_id = p_group and user_id = p_user
      ) as ok
    ),
    my_missing as (select sticker_id from public.v_user_missing where user_id = p_user),
    my_avail   as (select sticker_id from public.v_user_available where user_id = p_user),
    others as (
      select gm.user_id as id
      from public.group_members gm, authorized a
      where a.ok and gm.group_id = p_group and gm.user_id <> p_user
    ),
    they_give as (
      select va.user_id as other_user, count(*)::int as n
      from public.v_user_available va
      join my_missing m on m.sticker_id = va.sticker_id
      where va.user_id in (select id from others)
      group by va.user_id
    ),
    i_give as (
      select vm.user_id as other_user, count(*)::int as n
      from public.v_user_missing vm
      join my_avail a on a.sticker_id = vm.sticker_id
      where vm.user_id in (select id from others)
      group by vm.user_id
