-- ==========================================================
-- FIGURITAS WC2026 - visibilidad de miembros de grupos
-- Ejecutar en Supabase SQL Editor.
--
-- Permite que integrantes de un mismo grupo cerrado puedan verse
-- entre si, aunque su perfil no este abierto a toda la comunidad.
-- No hace publicos los perfiles privados fuera de sus grupos.
-- ==========================================================

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select
  using (
    visibility = 'public'
    or id = auth.uid()
    or exists (
      select 1
      from public.group_members mine
      join public.group_members theirs on theirs.group_id = mine.group_id
      where mine.user_id = auth.uid()
        and theirs.user_id = profiles.id
    )
  );

drop policy if exists group_members_read_own on public.group_members;
drop policy if exists group_members_read_group on public.group_members;
create policy group_members_read_group on public.group_members for select
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.group_members mine
      where mine.group_id = group_members.group_id
        and mine.user_id = auth.uid()
    )
  );
