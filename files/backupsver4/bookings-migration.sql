-- ══════════════════════════════════════════════════════════════
--  SHUTTERLITE — Migração: Marcação de Sessões (sl_bookings)
--
--  Este script é INCREMENTAL: só cria a tabela nova de bookings.
--  NÃO apaga nem afeta nenhuma tabela existente (sessions, photos,
--  services, messages, etc.) — é seguro correr numa base de dados
--  já em produção.
--
--  Como aplicar:
--    Supabase → SQL Editor → cole este script INTEIRO → Run
-- ══════════════════════════════════════════════════════════════

-- ── TABELA ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sl_bookings (
  id             BIGSERIAL PRIMARY KEY,
  code           TEXT UNIQUE NOT NULL,          -- código único do pedido (ex: SL-20260819-A9F3)

  -- Contacto
  name           TEXT NOT NULL,
  phone          TEXT NOT NULL,
  email          TEXT NOT NULL,

  -- Detalhes da sessão
  session_type   TEXT NOT NULL,
  package        TEXT NOT NULL,
  session_date   DATE NOT NULL,
  session_time   TIME NOT NULL,
  duration       TEXT NOT NULL,
  people         INT NOT NULL DEFAULT 1,
  style          TEXT NOT NULL,

  -- Local
  location       TEXT NOT NULL,                 -- Estúdio | Exterior | Domicílio | Outro
  address        TEXT,                          -- obrigatório apenas quando location != Estúdio

  -- Observações e pagamento
  notes          TEXT,
  payment_method TEXT NOT NULL,

  -- Gestão do pedido (uso do admin)
  status         TEXT NOT NULL DEFAULT 'pendente'
                 CHECK (status IN ('pendente','confirmado','recusado','concluido','cancelado')),
  admin_notes    TEXT,                          -- notas internas, não visíveis ao cliente

  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bookings_status  ON sl_bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_date    ON sl_bookings(session_date);
CREATE INDEX IF NOT EXISTS idx_bookings_created ON sl_bookings(created_at);

-- ── AUTO-UPDATE de updated_at ────────────────────────────────────
CREATE OR REPLACE FUNCTION sl_bookings_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sl_bookings_updated_at ON sl_bookings;
CREATE TRIGGER trg_sl_bookings_updated_at
  BEFORE UPDATE ON sl_bookings
  FOR EACH ROW EXECUTE FUNCTION sl_bookings_set_updated_at();

-- ── RLS ───────────────────────────────────────────────────────────
ALTER TABLE sl_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_bookings" ON sl_bookings;
CREATE POLICY "anon_all_bookings" ON sl_bookings FOR ALL TO anon USING (true) WITH CHECK (true);

-- ── PostgREST cache reload ────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ══════════════════════════════════════════════════════════════
--  DONE. A tabela sl_bookings está pronta a receber pedidos
--  vindos do formulário público e a ser gerida em admin.html.
-- ══════════════════════════════════════════════════════════════
