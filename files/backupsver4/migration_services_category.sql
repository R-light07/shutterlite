-- ══════════════════════════════════════════════════════════════
--  MIGRATION — Liga Serviços a Categorias
--  (não apaga nada, seguro correr na base de dados já em produção)
--
--  Como correr:
--    Supabase → SQL Editor → cole este script → Run
-- ══════════════════════════════════════════════════════════════

ALTER TABLE sl_services
  ADD COLUMN IF NOT EXISTS category_id BIGINT REFERENCES sl_categories(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_services_cat ON sl_services(category_id);

-- Recarregar cache da API para reconhecer a nova coluna
NOTIFY pgrst, 'reload schema';

-- ══════════════════════════════════════════════════════════════
--  DONE. Depois de correr isto:
--    1. Vá ao Admin → Serviços → edite cada serviço
--    2. Escolha a "Categoria" correspondente (ex: Wedding Photography → Wedding)
--    3. Garanta que existe pelo menos uma Sessão com essa categoria e fotos
-- ══════════════════════════════════════════════════════════════
