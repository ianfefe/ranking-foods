-- Extensões usadas pelo app (P0). O schema do domínio entra na P1.
-- postgis:  busca "perto de mim" (geography, ST_DWithin)
-- pg_trgm:  busca textual aproximada por nome de restaurante/prato
-- unaccent: busca ignorando acentos ("feijoada" encontra "Feijoáda")
create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
