-- ==========================================================
-- FIGUS2026 - arreglo de coincidencias dentro de grupos
-- Ejecutar en Supabase > SQL Editor.
--
-- No borra datos. Reinstala la funcion que calcula:
-- - figuritas que otros miembros del grupo te pueden dar
-- - figuritas repetidas tuyas que otros miembros necesitan
-- ==========================================================

drop function if exists public.f_group_matches(uuid, uuid);

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
  they_give_list text[],
  i_give_list text[],
  score int,
  group_name text
)
language sql
stable
security definer
set search_path = public
as $$
  with
    authorized as (
      select auth.uid() = p_user
        and exists (
          select 1
          from public.group_members gm
          where gm.group_id = p_group
            and gm.user_id = p_user
        ) as ok
    ),
    others as (
      select gm.user_id as id
      from public.group_members gm
      cross join authorized a
      where a.ok
        and gm.group_id = p_group
        and gm.user_id <> p_user
    ),
    my_missing as (
      select s.id as sticker_id
      from public.stickers s
      left join public.user_stickers us
        on us.sticker_id = s.id
       and us.user_id = p_user
      where coalesce(us."count", 0) = 0
    ),
    my_avail as (
      select us.sticker_id
      from public.user_stickers us
      where us.user_id = p_user
        and us."count" >= 2
    ),
    they_give as (
      select
        us.user_id as other_user,
        count(*)::int as n,
        array_agg(
          split_part(us.sticker_id, '-', 1) || ' ' || (split_part(us.sticker_id, '-', 2)::int)::text
          order by split_part(us.sticker_id, '-', 1), split_part(us.sticker_id, '-', 2)::int
        ) as items
      from public.user_stickers us
      join my_missing mm on mm.sticker_id = us.sticker_id
      where us.user_id in (select id from others)
        and us."count" >= 2
      group by us.user_id
    ),
    i_give as (
      select
        o.id as other_user,
        count(*)::int as n,
        array_agg(
          split_part(ma.sticker_id, '-', 1) || ' ' || (split_part(ma.sticker_id, '-', 2)::int)::text
          order by split_part(ma.sticker_id, '-', 1), split_part(ma.sticker_id, '-', 2)::int
        ) as items
      from others o
      join my_avail ma on true
      left join public.user_stickers ous
        on ous.user_id = o.id
       and ous.sticker_id = ma.sticker_id
      where coalesce(ous."count", 0) = 0
      group by o.id
    )
  select
    p.id as other_user,
    p.display_name,
    p.zone,
    p.city,
    p.country,
    p.whatsapp,
    coalesce(tg.n, 0) as they_give_me,
    coalesce(ig.n, 0) as i_give_them,
    coalesce(tg.items, array[]::text[]) as they_give_list,
    coalesce(ig.items, array[]::text[]) as i_give_list,
    (least(coalesce(tg.n, 0), coalesce(ig.n, 0)) * 2
      + coalesce(tg.n, 0)
      + coalesce(ig.n, 0))::int as score,
    g.name as group_name
  from others o
  join public.profiles p on p.id = o.id
  join public.groups g on g.id = p_group
  left join they_give tg on tg.other_user = p.id
  left join i_give ig on ig.other_user = p.id
  where (coalesce(tg.n, 0) + coalesce(ig.n, 0)) > 0
  order by score desc, p.display_name asc;
$$;

grant execute on function public.f_group_matches(uuid, uuid) to authenticated;

-- Diagnostico rapido: si el grupo existe, deberias ver sus miembros.
-- Reemplaza el codigo si queres revisar otro grupo.
select
  g.name as grupo,
  g.invite_code as codigo,
  p.id as user_id,
  p.display_name as miembro,
  gm.role as rol
from public.groups g
join public.group_members gm on gm.group_id = g.id
join public.profiles p on p.id = gm.user_id
where g.invite_code = '2D172946'
order by gm.joined_at;
