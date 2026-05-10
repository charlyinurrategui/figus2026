-- ==========================================================
-- FIGURITAS WC2026 - correccion de nombres del catalogo
-- Ejecutar en Supabase SQL Editor.
--
-- Este patch NO borra datos: solo cambia el nombre/categoria de
-- las figuritas de paises ya existentes.
-- ==========================================================

-- La 001 sigue siendo el escudo de cada pais.
update public.stickers
set
  name = team_name || ' - Escudo',
  category = 'team'
where team_code is not null
  and team_code not in ('FIFA', 'CC')
  and right(id, 3) = '001';

-- Sacamos el numero de jugador de todas las figuritas de pais.
update public.stickers
set
  name = team_name,
  category = 'player'
where team_code is not null
  and team_code not in ('FIFA', 'CC')
  and right(id, 3) between '002' and '020'
  and right(id, 3) <> '013';

-- En todos los paises, la 013 es la seleccion completa.
update public.stickers
set
  name = team_name || ' - Seleccion completa',
  category = 'team'
where team_code is not null
  and team_code not in ('FIFA', 'CC')
  and right(id, 3) = '013';
