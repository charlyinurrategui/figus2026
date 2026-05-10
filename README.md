# Figuritas Mundial 2026 — App de intercambio

MVP de una web app responsive para cargar el álbum del Mundial 2026 (980 figuritas), ver faltantes, marcar repetidas disponibles y matchear con otros usuarios para intercambiar.

## Archivos

- `figuritas-app.html` — App single-file (HTML + CSS + JS) lista para abrir en cualquier navegador o subir a Vercel/Netlify/GitHub Pages.
- `supabase-schema.sql` — Schema de Postgres con tablas, vistas, función de matching y RLS. Incluye seed de las 980 figuritas.

## Cómo probarla ya (modo offline)

1. Abrí `figuritas-app.html` en Chrome/Safari/Firefox (mobile o desktop).
2. Tocá una figurita → ajustá la cantidad (0 = falta, 1 = pegada, 2+ = repetidas).
3. Las pestañas inferiores muestran: Álbum, Faltan, Cambio (repetidas), Match, Yo (perfil).
4. La pestaña **Match** muestra usuarios demo precargados — sirve para ver el flujo end-to-end (incluyendo botón de WhatsApp).
5. Todo se guarda en `localStorage` del navegador. Podés exportar/importar JSON desde el perfil.

## Conectar Supabase (modo online)

1. Crear un proyecto en https://supabase.com.
2. SQL Editor → pegar y ejecutar `supabase-schema.sql`. Esto crea las tablas, RLS, vistas, la función `f_matches(user_id)` y carga las 980 figuritas.
3. Authentication → Providers → activar **Email** con login por contraseña.
4. En la app: login inicial o pestaña **Yo** → pegar Project URL y `anon key` (Settings → API).
5. Crear cuenta con email + contraseña o iniciar sesión. El progreso se sincroniza en `user_stickers` y se recupera al volver a entrar.

## Modelo de datos

| Tabla | Para qué |
|---|---|
| `profiles` | Datos del usuario (nombre, WhatsApp, ciudad, visibilidad). Una fila por `auth.users`. |
| `stickers` | Catálogo de las 980 figuritas (id, número, equipo, categoría, rareza). |
| `user_stickers` | Inventario de cada usuario (`count` por sticker). |
| `messages` | Chat directo entre usuarios. |
| `v_user_missing` | Vista derivada: faltantes por usuario. |
| `v_user_available` | Vista derivada: repetidas (count ≥ 2) listas para intercambio. |
| `f_matches(uuid)` | Función SQL que devuelve usuarios con score de coincidencia. |

## Algoritmo de matching

Para un usuario A y otro usuario B:

- `they_give_me` = | A.faltantes ∩ B.disponibles |
- `i_give_them`  = | B.faltantes ∩ A.disponibles |
- `score` = `min(theyGiveMe, iGiveThem) * 2 + theyGiveMe + iGiveThem`

El factor `min(...) * 2` premia los matches **bidireccionales** (los más justos para un cambio cara a cara).

## Funcionalidades del MVP

- [x] Álbum agrupado por país, con búsqueda por nombre / número / código.
- [x] Buscador rápido por código de figurita (`ARG12`, `ARG-012`) que indica si falta, está pegada o es repetida.
- [x] Marcado rápido +/- por figurita con modal.
- [x] Stats: total, pegadas, faltan, repetidas.
- [x] Vista de **faltantes** (con copiar lista).
- [x] Vista de **repetidas/disponibles** (con copiar lista).
- [x] Matching con tres modos: bidireccional / "tienen lo que me falta" / "necesitan lo que me sobra".
- [x] Botón de **WhatsApp** con mensaje precargado para coordinar el cambio.
- [x] Perfil editable + export/import JSON.
- [x] Login con email + contraseña usando Supabase Auth.
- [x] Schema Supabase completo con RLS y matching server-side.

## Próximos pasos sugeridos

1. **Recuperación de contraseña** desde Supabase Auth para usuarios que olviden su clave.
2. **Sync bidireccional avanzado** con resolución por fecha cuando el mismo usuario edita offline en dos dispositivos.
3. **Imágenes reales** de las figuritas (bucket de Supabase Storage o CDN propio). Hoy usamos emojis y textos.
4. **Chat in-app** sobre la tabla `messages` (Realtime de Supabase) en lugar de salto a WhatsApp.
5. **PWA**: agregar `manifest.json` + service worker para instalación en móvil y uso offline persistente.
6. **Verificación**: validar las 48 selecciones contra la lista oficial de FIFA cuando se publique. La estructura de IDs (`<COD>-<NN>`) se mantiene sin importar el equipo.
7. **Editor de álbum**: panel admin para subir CSV con nombres de jugadores reales sin tocar código.

## Stack

- Frontend: HTML + JS vanilla, sin framework. Single-file para portabilidad.
- Estado local: `localStorage`.
- Backend: Supabase (Postgres + Auth + Realtime + Storage). Carga del SDK por CDN en el momento de conectar.
- Hosting recomendado: Vercel, Netlify o GitHub Pages — el HTML es estático.
