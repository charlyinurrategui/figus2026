# Figuritas Mundial 2026 — App de intercambio

MVP de una web app responsive para cargar el álbum del Mundial 2026 (980 figuritas), ver faltantes, marcar repetidas disponibles y matchear con otros usuarios para intercambiar.
MVP de una web app responsive para cargar el álbum del Mundial 2026 (993 figuritas), ver faltantes, marcar repetidas disponibles y matchear con otros usuarios para intercambiar.

## Archivos

- `figuritas-app.html` — App single-file (HTML + CSS + JS) lista para abrir en cualquier navegador o subir a Vercel/Netlify/GitHub Pages.
- `supabase-schema.sql` — Schema de Postgres con tablas, vistas, función de matching y RLS. Incluye seed de las 980 figuritas.
- `supabase-schema.sql` — Schema de Postgres con tablas, vistas, funciones de matching, grupos cerrados y RLS. Incluye seed de las 993 figuritas.

## Cómo probarla ya (modo offline)

1. Abrí `figuritas-app.html` en Chrome/Safari/Firefox (mobile o desktop).
2. Tocá una figurita → ajustá la cantidad (0 = falta, 1 = pegada, 2+ = repetidas).
3. Las pestañas inferiores muestran: Álbum, Faltan, Cambio (repetidas), Match, Yo (perfil).
4. La pestaña **Match** muestra usuarios demo precargados — sirve para ver el flujo end-to-end (incluyendo botón de WhatsApp).
5. Todo se guarda en `localStorage` del navegador. Podés exportar/importar JSON desde el perfil.
4. En **Faltan** podés copiar la lista o generar un PDF imprimible agrupado por país.
5. La pestaña **Match** muestra usuarios demo precargados — sirve para ver el flujo end-to-end (incluyendo botón de WhatsApp).
6. Todo se guarda en `localStorage` del navegador. Podés exportar/importar JSON desde el perfil.

## Conectar Supabase (modo online)

1. Crear un proyecto en https://supabase.com.
2. SQL Editor → pegar y ejecutar `supabase-schema.sql`. Esto crea las tablas, RLS, vistas, la función `f_matches(user_id)` y carga las 980 figuritas.
2. SQL Editor → pegar y ejecutar `supabase-schema.sql`. Esto crea las tablas, RLS, vistas, funciones de matching y carga las 993 figuritas.
3. Authentication → Providers → activar **Email** con login por contraseña.
4. En la app: login inicial o pestaña **Yo** → pegar Project URL y `anon key` (Settings → API).
5. Crear cuenta con email + contraseña o iniciar sesión. El progreso se sincroniza en `user_stickers` y se recupera al volver a entrar.
6. Para grupos cerrados, usá la pestaña **Match**: crear grupo genera un código de invitación, y otros usuarios pueden unirse con ese código. Al elegir un grupo activo, los matches se limitan a sus integrantes.

## Modelo de datos

| Tabla | Para qué |
|---|---|
| `profiles` | Datos del usuario (nombre, WhatsApp, ciudad, visibilidad). Una fila por `auth.users`. |
| `stickers` | Catálogo de las 980 figuritas (id, número, equipo, categoría, rareza). |
| `stickers` | Catálogo de las 993 figuritas (id, número, equipo, categoría, rareza). |
| `user_stickers` | Inventario de cada usuario (`count` por sticker). |
| `messages` | Chat directo entre usuarios. |
| `groups` | Grupos cerrados con código de invitación. |
| `group_members` | Integrantes y rol dentro de cada grupo. |
| `v_user_missing` | Vista derivada: faltantes por usuario. |
| `v_user_available` | Vista derivada: repetidas (count ≥ 2) listas para intercambio. |
| `f_matches(uuid)` | Función SQL que devuelve usuarios con score de coincidencia. |
| `f_group_matches(uuid, uuid)` | Función SQL que devuelve matches limitados a un grupo cerrado. |
| `create_closed_group(text)` | Crea un grupo cerrado y suma al usuario como owner. |
| `join_closed_group(text)` | Une al usuario al grupo correspondiente al código. |

## Algoritmo de matching

- [x] Marcado rápido +/- por figurita con modal.
- [x] Stats: total, pegadas, faltan, repetidas.
- [x] Vista de **faltantes** (con copiar lista).
- [x] PDF imprimible de faltantes agrupadas por país.
- [x] Vista de **repetidas/disponibles** (con copiar lista).
- [x] Matching con tres modos: bidireccional / "tienen lo que me falta" / "necesitan lo que me sobra".
- [x] Grupos cerrados con código de invitación para matchear solo entre integrantes.
- [x] Botón de **WhatsApp** con mensaje precargado para coordinar el cambio.
- [x] Perfil editable + export/import JSON.
- [x] Login con email + contraseña usando Supabase Auth.
