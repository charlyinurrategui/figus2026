-- Agrega el modo de uso del perfil sin borrar datos.
-- Ejecutar una sola vez en Supabase SQL Editor.

alter table public.profiles
  add column if not exists share_mode text not null default 'groups';

alter table public.profiles
  drop constraint if exists profiles_share_mode_check;

alter table public.profiles
  add constraint profiles_share_mode_check
  check (share_mode in ('private', 'groups', 'public'));

update public.profiles
set share_mode = case
  when visibility = 'public' then 'public'
  when coalesce(share_mode, '') not in ('private', 'groups', 'public') then 'groups'
  else share_mode
end;
