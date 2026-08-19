-- ══════════════════════════════════════════════════════════════
--  SHUTTERLITE PORTFOLIO — Supabase Full Setup (v2 — sessions)
--
--  Antes de correr este script:
--    1. Storage → New bucket → nome: portfolio-media → Public: ON
--    2. SQL Editor → cole este script INTEIRO → Run
--  Inclui: schema novo + RLS + policies de storage + seed data
-- ══════════════════════════════════════════════════════════════

-- ── 0. LIMPAR ESTRUTURA ANTIGA ────────────────────────────────
DROP TABLE IF EXISTS sl_photos         CASCADE;
DROP TABLE IF EXISTS sl_sessions       CASCADE;
DROP TABLE IF EXISTS sl_categories     CASCADE;
DROP TABLE IF EXISTS sl_service_photos CASCADE;
DROP TABLE IF EXISTS sl_services       CASCADE;
DROP TABLE IF EXISTS sl_testimonials CASCADE;
DROP TABLE IF EXISTS sl_messages     CASCADE;
DROP TABLE IF EXISTS sl_settings     CASCADE;
DROP TABLE IF EXISTS sl_social       CASCADE;
DROP TABLE IF EXISTS sl_admins       CASCADE;
DROP TABLE IF EXISTS sl_bookings     CASCADE;

-- ── 1. ADMIN USERS ────────────────────────────────────────────
CREATE TABLE sl_admins (
  id            BIGSERIAL PRIMARY KEY,
  username      TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. CATEGORIES (tags opcionais para sessões) ───────────────
CREATE TABLE sl_categories (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  description TEXT,
  sort_order  INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── 3. SESSIONS (unidade principal — cada card no portfolio) ──
CREATE TABLE sl_sessions (
  id             BIGSERIAL PRIMARY KEY,
  title          TEXT NOT NULL,
  slug           TEXT UNIQUE NOT NULL,
  description    TEXT,
  category_id    BIGINT REFERENCES sl_categories(id) ON DELETE SET NULL,
  event_date     DATE,
  location       TEXT,
  cover_photo_id BIGINT, -- FK adicionada após criação de sl_photos
  cover_in_hero  BOOLEAN DEFAULT FALSE,
  sort_order     INT DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── 4. PHOTOS (cada foto pertence a uma sessão) ───────────────
CREATE TABLE sl_photos (
  id           BIGSERIAL PRIMARY KEY,
  session_id   BIGINT REFERENCES sl_sessions(id) ON DELETE CASCADE,
  title        TEXT,
  description  TEXT,
  storage_path TEXT NOT NULL,
  public_url   TEXT NOT NULL,
  is_cover     BOOLEAN DEFAULT FALSE,
  sort_order   INT DEFAULT 0,
  uploaded_at  TIMESTAMPTZ DEFAULT NOW()
);

-- FK circular: cover_photo_id -> sl_photos
ALTER TABLE sl_sessions
  ADD CONSTRAINT fk_session_cover
  FOREIGN KEY (cover_photo_id) REFERENCES sl_photos(id) ON DELETE SET NULL;

-- ── 5. SERVICES ───────────────────────────────────────────────
CREATE TABLE sl_services (
  id             BIGSERIAL PRIMARY KEY,
  title          TEXT NOT NULL,
  slug           TEXT UNIQUE NOT NULL,
  description    TEXT,
  price_from     TEXT,
  icon           TEXT,
  features       TEXT[],
  cover_photo_id BIGINT, -- FK adicionada após criação de sl_service_photos
  sort_order     INT DEFAULT 0,
  is_active      BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── 5b. SERVICE PHOTOS (imagens específicas de cada serviço) ──
CREATE TABLE sl_service_photos (
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

-- FK circular: cover_photo_id -> sl_service_photos
ALTER TABLE sl_services
  ADD CONSTRAINT fk_service_cover
  FOREIGN KEY (cover_photo_id) REFERENCES sl_service_photos(id) ON DELETE SET NULL;

-- ── 6. TESTIMONIALS ───────────────────────────────────────────
CREATE TABLE sl_testimonials (
  id          BIGSERIAL PRIMARY KEY,
  client_name TEXT NOT NULL,
  client_role TEXT,
  content     TEXT NOT NULL,
  rating      INT DEFAULT 5 CHECK (rating BETWEEN 1 AND 5),
  avatar_url  TEXT,
  is_featured BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── 7. CONTACT MESSAGES ───────────────────────────────────────
CREATE TABLE sl_messages (
  id               BIGSERIAL PRIMARY KEY,
  name             TEXT NOT NULL,
  email            TEXT NOT NULL,
  phone            TEXT,
  service_interest TEXT,
  message          TEXT NOT NULL,
  is_read          BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── 8. SITE SETTINGS ──────────────────────────────────────────
CREATE TABLE sl_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 9. SOCIAL LINKS ───────────────────────────────────────────
CREATE TABLE sl_social (
  id         BIGSERIAL PRIMARY KEY,
  platform   TEXT NOT NULL,
  url        TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  is_active  BOOLEAN DEFAULT TRUE
);

-- ── 10. BOOKINGS (pedidos de marcação de sessões) ─────────────
CREATE TABLE sl_bookings (
  id             BIGSERIAL PRIMARY KEY,
  code           TEXT UNIQUE NOT NULL,

  name           TEXT NOT NULL,
  phone          TEXT NOT NULL,
  email          TEXT NOT NULL,

  session_type   TEXT NOT NULL,
  package        TEXT NOT NULL,
  session_date   DATE NOT NULL,
  session_time   TIME NOT NULL,
  duration       TEXT NOT NULL,
  people         INT NOT NULL DEFAULT 1,
  style          TEXT NOT NULL,

  location       TEXT NOT NULL,
  address        TEXT,

  notes          TEXT,
  payment_method TEXT NOT NULL,

  status         TEXT NOT NULL DEFAULT 'pendente'
                 CHECK (status IN ('pendente','confirmado','recusado','concluido','cancelado')),
  admin_notes    TEXT,

  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION sl_bookings_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sl_bookings_updated_at
  BEFORE UPDATE ON sl_bookings
  FOR EACH ROW EXECUTE FUNCTION sl_bookings_set_updated_at();

-- ── INDEXES ───────────────────────────────────────────────────
CREATE INDEX idx_photos_session   ON sl_photos(session_id);
CREATE INDEX idx_photos_cover     ON sl_photos(is_cover);
CREATE INDEX idx_sessions_cat     ON sl_sessions(category_id);
CREATE INDEX idx_sessions_hero    ON sl_sessions(cover_in_hero);
CREATE INDEX idx_messages_read    ON sl_messages(is_read);
CREATE INDEX idx_service_photos_service ON sl_service_photos(service_id);
CREATE INDEX idx_services_slug    ON sl_services(slug);
CREATE INDEX idx_bookings_status  ON sl_bookings(status);
CREATE INDEX idx_bookings_date    ON sl_bookings(session_date);
CREATE INDEX idx_bookings_created ON sl_bookings(created_at);

-- ══════════════════════════════════════════════════════════════
--  RLS — public read / anon full access
-- ══════════════════════════════════════════════════════════════
ALTER TABLE sl_admins       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_categories   ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_sessions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_photos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_services       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_service_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_testimonials ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_messages     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_social       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_bookings     ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_all_admins"       ON sl_admins       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_categories"   ON sl_categories   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_sessions"     ON sl_sessions     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_photos"       ON sl_photos       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_services"     ON sl_services     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_service_photos" ON sl_service_photos FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_testimonials" ON sl_testimonials FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_messages"     ON sl_messages     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_settings"     ON sl_settings     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_social"       ON sl_social       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_bookings"     ON sl_bookings     FOR ALL TO anon USING (true) WITH CHECK (true);

-- ══════════════════════════════════════════════════════════════
--  STORAGE POLICIES — bucket portfolio-media (criar manualmente)
-- ══════════════════════════════════════════════════════════════

-- objects: CRUD para anon
DO $$
DECLARE pol RECORD;
BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
             WHERE schemaname='storage' AND tablename='objects'
             AND policyname LIKE 'sl_%'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
  END LOOP;
END $$;

CREATE POLICY "sl_storage_select" ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id = 'portfolio-media');
CREATE POLICY "sl_storage_insert" ON storage.objects FOR INSERT TO anon, authenticated WITH CHECK (bucket_id = 'portfolio-media');
CREATE POLICY "sl_storage_update" ON storage.objects FOR UPDATE TO anon, authenticated USING (bucket_id = 'portfolio-media') WITH CHECK (bucket_id = 'portfolio-media');
CREATE POLICY "sl_storage_delete" ON storage.objects FOR DELETE TO anon, authenticated USING (bucket_id = 'portfolio-media');



