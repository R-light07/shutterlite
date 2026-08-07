-- ══════════════════════════════════════════════════════════════
--  SHUTTERLITE — Migração: Imagens dinâmicas por Serviço
--
--  Use este script APENAS se já correu o setup.sql antigo e tem
--  dados em produção (sessões, testemunhos, mensagens, etc).
--  Ele NÃO apaga nada — só adiciona o que falta.
--
--  Como correr: Supabase → SQL Editor → cole este script → Run
-- ══════════════════════════════════════════════════════════════

-- ── 1. Novas colunas em sl_services ────────────────────────────
ALTER TABLE sl_services ADD COLUMN IF NOT EXISTS slug TEXT;
ALTER TABLE sl_services ADD COLUMN IF NOT EXISTS cover_photo_id BIGINT;

-- ── 2. Tabela de imagens por serviço ───────────────────────────
CREATE TABLE IF NOT EXISTS sl_service_photos (
  id           BIGSERIAL PRIMARY KEY,
  service_id   BIGINT REFERENCES sl_services(id) ON DELETE CASCADE,
  title        TEXT,
  description  TEXT,
  storage_path TEXT NOT NULL,
  public_url   TEXT NOT NULL,
  is_cover     BOOLEAN DEFAULT FALSE,
  sort_order   INT DEFAULT 0,
  uploaded_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── 3. FK circular cover_photo_id -> sl_service_photos ─────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_service_cover'
  ) THEN
    ALTER TABLE sl_services
      ADD CONSTRAINT fk_service_cover
      FOREIGN KEY (cover_photo_id) REFERENCES sl_service_photos(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ── 4. Preencher slugs em falta a partir do título ─────────────
UPDATE sl_services
SET slug = trim(both '-' from lower(regexp_replace(title, '[^a-zA-Z0-9]+', '-', 'g')))
WHERE slug IS NULL OR slug = '';

-- Resolver colisões de slug (ex.: dois serviços com o mesmo nome)
UPDATE sl_services s
SET slug = s.slug || '-' || s.id
WHERE EXISTS (
  SELECT 1 FROM sl_services s2 WHERE s2.slug = s.slug AND s2.id <> s.id
);

-- Garantir unicidade e obrigatoriedade do slug daqui para a frente
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'sl_services_slug_unique'
  ) THEN
    ALTER TABLE sl_services ADD CONSTRAINT sl_services_slug_unique UNIQUE (slug);
  END IF;
END $$;
ALTER TABLE sl_services ALTER COLUMN slug SET NOT NULL;

-- ── 5. Índices ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_service_photos_service ON sl_service_photos(service_id);
CREATE INDEX IF NOT EXISTS idx_services_slug ON sl_services(slug);

-- ── 6. RLS — mesmo modelo (anon full access) das outras tabelas ─
ALTER TABLE sl_service_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_service_photos" ON sl_service_photos;
CREATE POLICY "anon_all_service_photos" ON sl_service_photos FOR ALL TO anon USING (true) WITH CHECK (true);

-- (As policies de storage.objects para o bucket "portfolio-media"
--  criadas pelo setup.sql original já cobrem os novos ficheiros —
--  não é preciso nada extra no Storage.)

-- ── PostgREST cache reload ────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ══════════════════════════════════════════════════════════════
--  DONE. Próximos passos:
--    1. Vá ao Admin → Serviços → edite cada serviço e confirme/
--       ajuste o "slug" (URL amigável) gerado automaticamente.
--    2. Abra cada serviço → adicione fotos na secção de galeria.
-- ══════════════════════════════════════════════════════════════
