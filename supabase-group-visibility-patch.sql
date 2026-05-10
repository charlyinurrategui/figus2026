-- ==========================================================
-- FIGURITAS WC2026 - visibilidad de miembros de grupos
-- Ejecutar en Supabase SQL Editor.
--
-- Permite que integrantes de un mismo grupo cerrado puedan verse
-- entre si, aunque su perfil no este abierto a toda la comunidad.
-- No hace publicos los perfiles privados fuera de sus grupos.
-- ==========================================================

create or replace function public.is_group_member(p_group uuid)
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members
    where group_id = p_group
      and user_id = auth.uid()
  );
$$;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select
  using (
    visibility = 'public'
    or id = auth.uid()
    or exists (
      select 1
      from public.group_members theirs
      where theirs.user_id = profiles.id
        and public.is_group_member(theirs.group_id)
    )
  );

drop policy if exists group_members_read_own on public.group_members;
drop policy if exists group_members_read_group on public.group_members;
create policy group_members_read_group on public.group_members for select
  using (
    user_id = auth.uid()
    or public.is_group_member(group_id)
  );
