-- =========================================================
-- FIGURITAS WC2026 - Supabase schema (Postgres + RLS)
-- Ejecutar en Supabase SQL Editor
-- =========================================================

-- 1) PROFILES (extiende auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  whatsapp text,
  zone text,           -- barrio/zona donde vive (ej: Palermo, Caballito)
  city text,
  country text,
  visibility text not null default 'public' check (visibility in ('public','private')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
-- migración por si la tabla ya existía
alter table public.profiles add column if not exists zone text;
create index if not exists profiles_zone_idx on public.profiles(zone);
create index if not exists profiles_city_idx on public.profiles(city);

-- 2) STICKERS (catálogo de las 980 figuritas)
create table if not exists public.stickers (
  id text primary key,            -- ej: ARG-012, FWC-001, CC-003
  album text not null default 'WC2026',
  num int not null,               -- número correlativo en el álbum (1..993)
  name text not null,
  category text not null check (category in ('fwc','team','player','cc')),
  team_code text,                 -- ARG, BRA, ...
  team_name text,
  confederation text,             -- CONMEBOL, UEFA, AFC, CAF, CONCACAF, OFC
  rarity text not null default 'base' check (rarity in ('base','gold','sponsor')),
  unique (album, num)
);
-- migración por si la tabla ya existía con el check anterior
do $$ begin
  begin
    alter table public.stickers drop constraint if exists stickers_category_check;
  exception when others then null; end;
  begin
    alter table public.stickers add constraint stickers_category_check
      check (category in ('fwc','team','player','cc'));
  exception when duplicate_object then null; end;
end $$;

create index if not exists stickers_team_idx    on public.stickers(team_code);
create index if not exists stickers_cat_idx     on public.stickers(category);

-- 3) USER_STICKERS (inventario por usuario)
create table if not exists public.user_stickers (
  user_id uuid references public.profiles(id) on delete cascade,
  sticker_id text references public.stickers(id) on delete cascade,
  count int not null default 0 check (count >= 0),
  updated_at timestamptz default now(),
  primary key (user_id, sticker_id)
);

create index if not exists user_stickers_uid_idx on public.user_stickers(user_id);
create index if not exists user_stickers_sid_idx on public.user_stickers(sticker_id);

-- 4) MESSAGES (chat directo entre usuarios)
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id    uuid references public.profiles(id) on delete cascade,
  recipient_id uuid references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz default now(),
  read_at    timestamptz
);

create index if not exists msg_recipient_idx on public.messages(recipient_id, created_at desc);

-- =========================================================
-- VISTAS DERIVADAS
-- =========================================================

-- Faltantes por usuario (count = 0 o sin registro)
create or replace view public.v_user_missing as
select p.id as user_id, s.id as sticker_id, s.num, s.name, s.team_code, s.category
from public.profiles p
cross join public.stickers s
left join public.user_stickers us on us.user_id = p.id and us.sticker_id = s.id
where coalesce(us.count, 0) = 0;

-- Disponibles para cambio (count >= 2)
create or replace view public.v_user_available as
select us.user_id, us.sticker_id, us.count - 1 as available_qty,
       s.num, s.name, s.team_code, s.category
from public.user_stickers us
join public.stickers s on s.id = us.sticker_id
where us.count >= 2;

-- =========================================================
-- FUNCIÓN DE MATCHING
-- =========================================================
-- Dado un user_id devuelve usuarios que tienen lo que me falta
-- y necesitan lo que me sobra, con score.
create or replace function public.f_matches(p_user uuid)
returns table (
  other_user uuid,
  display_name text,
  zone text,
  city text,
  country text,
  whatsapp text,
  they_give_me int,
  i_give_them int,
  score int
) language sql stable as $$
  with
    my_missing as (select sticker_id from public.v_user_missing where user_id = p_user),
    my_avail   as (select sticker_id from public.v_user_available where user_id = p_user),
    -- otros usuarios con visibility public
    others as (
      select id from public.profiles
      where id <> p_user and visibility = 'public'
    ),
    -- ellos me dan = lo que está en sus disponibles y me falta
    they_give as (
      select va.user_id as other_user, count(*)::int as n
      from public.v_user_available va
      join my_missing m on m.sticker_id = va.sticker_id
      where va.user_id in (select id from others)
      group by va.user_id
    ),
    -- yo les doy = lo que está en sus faltantes y yo tengo repetidas
    i_give as (
      select vm.user_id as other_user, count(*)::int as n
      from public.v_user_missing vm
      join my_avail a on a.sticker_id = vm.sticker_id
      where vm.user_id in (select id from others)
      group by vm.user_id
    )
  select
    p.id, p.display_name, p.zone, p.city, p.country, p.whatsapp,
    coalesce(tg.n, 0) as they_give_me,
    coalesce(ig.n, 0) as i_give_them,
    (least(coalesce(tg.n,0), coalesce(ig.n,0)) * 2 + coalesce(tg.n,0) + coalesce(ig.n,0))::int as score
  from public.profiles p
  left join they_give tg on tg.other_user = p.id
  left join i_give    ig on ig.other_user = p.id
  where p.id <> p_user and p.visibility = 'public'
    and (coalesce(tg.n,0) + coalesce(ig.n,0)) > 0
  order by score desc;
$$;

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================
alter table public.profiles       enable row level security;
alter table public.user_stickers  enable row level security;
alter table public.messages       enable row level security;
alter table public.stickers       enable row level security;

-- Stickers: lectura pública
drop policy if exists stickers_read on public.stickers;
create policy stickers_read on public.stickers for select using (true);

-- Profiles: ver perfiles públicos o el propio
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select
  using (visibility = 'public' or id = auth.uid());

drop policy if exists profiles_upsert_self on public.profiles;
create policy profiles_upsert_self on public.profiles for insert with check (id = auth.uid());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update using (id = auth.uid());

-- User_stickers: cada usuario maneja lo suyo (lectura: solo el dueño;
-- el matching pasa por la vista/función con SECURITY DEFINER si fuera necesario)
drop policy if exists us_select_own on public.user_stickers;
create policy us_select_own on public.user_stickers for select using (user_id = auth.uid());

drop policy if exists us_modify_own on public.user_stickers;
create policy us_modify_own on public.user_stickers for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Messages: solo emisor o receptor
drop policy if exists msg_read on public.messages;
create policy msg_read on public.messages for select
  using (sender_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists msg_send on public.messages;
create policy msg_send on public.messages for insert with check (sender_id = auth.uid());

-- =========================================================
-- TRIGGER: crear profile cuando se registra un user
-- =========================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- =========================================================
-- SEED DE FIGURITAS (993)
-- Estructura: FWC 1-8, 48 equipos × 20, FWC 9-19, CC 1-14
-- =========================================================
truncate public.stickers cascade;

do $$
declare
  teams text[][] := array[
    array['MEX','México','CONCACAF'], array['RSA','Sudáfrica','CAF'], array['KOR','Corea del Sur','AFC'],
    array['CZE','Chequia','UEFA'], array['CAN','Canadá','CONCACAF'], array['BIH','Bosnia-Herzegovina','UEFA'],
    array['QAT','Catar','AFC'], array['SUI','Suiza','UEFA'], array['BRA','Brasil','CONMEBOL'],
    array['MAR','Marruecos','CAF'], array['HAI','Haití','CONCACAF'], array['SCO','Escocia','UEFA'],
    array['USA','Estados Unidos','CONCACAF'], array['PAR','Paraguay','CONMEBOL'], array['AUS','Australia','AFC'],
    array['TUR','Turquía','UEFA'], array['GER','Alemania','UEFA'], array['CUW','Curazao','CONCACAF'],
    array['CIV','Costa de Marfil','CAF'], array['ECU','Ecuador','CONMEBOL'], array['NED','Países Bajos','UEFA'],
    array['JPN','Japón','AFC'], array['SWE','Suecia','UEFA'], array['TUN','Túnez','CAF'],
    array['BEL','Bélgica','UEFA'], array['EGY','Egipto','CAF'], array['IRN','Irán','AFC'],
    array['NZL','Nueva Zelanda','OFC'], array['ESP','España','UEFA'], array['CPV','Cabo Verde','CAF'],
    array['KSA','Arabia Saudita','AFC'], array['URU','Uruguay','CONMEBOL'], array['FRA','Francia','UEFA'],
    array['SEN','Senegal','CAF'], array['IRQ','Irak','AFC'], array['NOR','Noruega','UEFA'],
    array['ARG','Argentina','CONMEBOL'], array['ALG','Argelia','CAF'], array['AUT','Austria','UEFA'],
    array['JOR','Jordania','AFC'], array['POR','Portugal','UEFA'], array['COD','RD del Congo','CAF'],
    array['UZB','Uzbekistán','AFC'], array['COL','Colombia','CONMEBOL'], array['ENG','Inglaterra','UEFA'],
    array['CRO','Croacia','UEFA'], array['GHA','Ghana','CAF'], array['PAN','Panamá','CONCACAF']
  ];
  i int; n int := 1;
  code text; cname text; conf text;
  j int;
begin
  -- 1) FWC 1-8
  for j in 1..8 loop
    insert into public.stickers (id, num, name, category, team_code, team_name)
      values ('FWC-'||lpad(j::text,3,'0'), n, 'FIFA World Cup '||j, 'fwc', 'FIFA', 'FIFA');
    n := n + 1;
  end loop;

  -- 2) 48 equipos × 20 figuritas = 960
  i := 1;
  while i <= array_length(teams, 1) loop
    code := teams[i][1]; cname := teams[i][2]; conf := teams[i][3];
    -- 01 = escudo
    insert into public.stickers (id, num, name, category, team_code, team_name, confederation)
      values (code||'-001', n, cname||' — Escudo',  'team', code, cname, conf);
    n := n + 1;
    -- 02 = plantel
    insert into public.stickers (id, num, name, category, team_code, team_name, confederation)
      values (code||'-002', n, cname||' — Plantel', 'team', code, cname, conf);
    n := n + 1;
    -- 03..20 = jugadores 1..18
    j := 1;
    while j <= 18 loop
      insert into public.stickers (id, num, name, category, team_code, team_name, confederation)
        values (code||'-'||lpad((j+2)::text,3,'0'), n, cname||' · Jugador '||j, 'player', code, cname, conf);
      n := n + 1;
      j := j + 1;
    end loop;
    i := i + 1;
  end loop;

  -- 3) FWC 9-19
  for j in 9..19 loop
    insert into public.stickers (id, num, name, category, team_code, team_name)
      values ('FWC-'||lpad(j::text,3,'0'), n, 'FIFA World Cup '||j, 'fwc', 'FIFA', 'FIFA');
    n := n + 1;
  end loop;

  -- 4) Coca-Cola CC 1-14
  for j in 1..14 loop
    insert into public.stickers (id, num, name, category, team_code, team_name, rarity)
      values ('CC-'||lpad(j::text,3,'0'), n, 'Coca-Cola '||j, 'cc', 'CC', 'Coca-Cola', 'sponsor');
    n := n + 1;
  end loop;
end $$;

-- Verificación
-- select count(*) from public.stickers;  -> debería ser 993
-- select category, count(*) from public.stickers group by 1;
-- fwc=19, team=96, player=864, cc=14
