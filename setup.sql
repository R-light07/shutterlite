-- ══════════════════════════════════════════════════════════════
--  SHUTTERLITE PORTFOLIO — Supabase Full Setup (v2 — sessions)
--
--  Antes de correr este script:
--    1. Storage → New bucket → nome: portfolio-media → Public: ON
--    2. SQL Editor → cole este script INTEIRO → Run
--  Inclui: schema novo + RLS + policies de storage + seed data
-- ══════════════════════════════════════════════════════════════

-- ── 0. LIMPAR ESTRUTURA ANTIGA ────────────────────────────────
DROP TABLE IF EXISTS sl_photos       CASCADE;
DROP TABLE IF EXISTS sl_sessions     CASCADE;
DROP TABLE IF EXISTS sl_categories   CASCADE;
DROP TABLE IF EXISTS sl_services     CASCADE;
DROP TABLE IF EXISTS sl_testimonials CASCADE;
DROP TABLE IF EXISTS sl_messages     CASCADE;
DROP TABLE IF EXISTS sl_settings     CASCADE;
DROP TABLE IF EXISTS sl_social       CASCADE;
DROP TABLE IF EXISTS sl_admins       CASCADE;

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
  id          BIGSERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT,
  price_from  TEXT,
  icon        TEXT,
  features    TEXT[],
  sort_order  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

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

-- ── INDEXES ───────────────────────────────────────────────────
CREATE INDEX idx_photos_session   ON sl_photos(session_id);
CREATE INDEX idx_photos_cover     ON sl_photos(is_cover);
CREATE INDEX idx_sessions_cat     ON sl_sessions(category_id);
CREATE INDEX idx_sessions_hero    ON sl_sessions(cover_in_hero);
CREATE INDEX idx_messages_read    ON sl_messages(is_read);

-- ══════════════════════════════════════════════════════════════
--  RLS — public read / anon full access
-- ══════════════════════════════════════════════════════════════
ALTER TABLE sl_admins       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_categories   ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_sessions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_photos       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_services     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_testimonials ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_messages     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sl_social       ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_all_admins"       ON sl_admins       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_categories"   ON sl_categories   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_sessions"     ON sl_sessions     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_photos"       ON sl_photos       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_services"     ON sl_services     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_testimonials" ON sl_testimonials FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_messages"     ON sl_messages     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_settings"     ON sl_settings     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_social"       ON sl_social       FOR ALL TO anon USING (true) WITH CHECK (true);

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

-- buckets: anon precisa ver o bucket
DROP POLICY IF EXISTS "sl_buckets_view" ON storage.buckets;
CREATE POLICY "sl_buckets_view" ON storage.buckets FOR SELECT TO anon, authenticated USING (true);

-- ══════════════════════════════════════════════════════════════
--  SEED DATA
-- ══════════════════════════════════════════════════════════════

-- Admin default — username: admin, password: admin123
INSERT INTO sl_admins (username, password_hash) VALUES
  ('admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9');

-- Categorias (tags opcionais)
INSERT INTO sl_categories (name, slug, sort_order) VALUES
  ('Wedding',    'wedding',    1),
  ('Portrait',   'portrait',   2),
  ('Editorial',  'editorial',  3),
  ('Corporate',  'corporate',  4),
  ('Event',      'event',      5);

-- Settings padrão
INSERT INTO sl_settings (key, value) VALUES
  ('photographer',     'Shutterlite'),
  ('tagline',          'Cinematic storytelling through elegant photography'),
  ('about_text',       'SHUTTERLITE is a premium photography brand focused on capturing authentic moments with cinematic elegance. Every image is crafted to preserve emotion, atmosphere and timeless beauty.'),
  ('about_since',      '2018'),
  ('hero_title',       'Capturing\nTimeless\nMoments'),
  ('hero_sub',         'Premium Photography Experience'),
  ('contact_email',    'contact@shutterlite.com'),
  ('contact_phone',    '+351 900 000 000'),
  ('contact_location', 'Lisbon, Portugal');

-- Serviços
INSERT INTO sl_services (title, description, price_from, sort_order) VALUES
  ('Wedding Photography',   'Cinematic coverage of your most important day, from preparations to the final dance.', 'From €1.200', 1),
  ('Event Coverage',        'Authentic documentation of corporate events, launches and private celebrations.',     'From €450',   2),
  ('Portrait Sessions',     'Editorial portraits crafted in studio or on location with a refined aesthetic.',      'From €250',   3),
  ('Commercial Photography','Brand-focused imagery for products, campaigns and visual identity.',                  'From €600',   4);

-- Testemunhos
INSERT INTO sl_testimonials (client_name, client_role, content, rating, is_featured) VALUES
  ('Ana & Miguel',  'Wedding, June 2025',   'An unforgettable experience. The photographs exceeded every expectation and captured every emotion beautifully.', 5, TRUE),
  ('Sofia Martins', 'Marketing Director',   'Working with SHUTTERLITE on our campaign was extraordinary. Professional, creative, and always on time.',       5, TRUE),
  ('Carlos Ferreira','Family Session',      'The family session was incredible. The kids loved it and the photos are simply perfect.',                          5, TRUE);

-- Redes sociais
INSERT INTO sl_social (platform, url, sort_order) VALUES
  ('Instagram', 'https://instagram.com/',  1),
  ('Facebook',  'https://facebook.com/',   2),
  ('Pinterest', 'https://pinterest.com/',  3),
  ('LinkedIn',  'https://linkedin.com/',   4);

-- ── PostgREST cache reload ────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ══════════════════════════════════════════════════════════════
--  DONE. Próximos passos:
--    1. Confirme bucket "portfolio-media" criado e PUBLIC
--    2. Login no admin com admin / admin123
--    3. Mude a password depois (em produção)
-- ══════════════════════════════════════════════════════════════
