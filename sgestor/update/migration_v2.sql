-- =====================================================================
-- Shutterlite · Migração v2 (ADITIVA – não apaga dados existentes)
-- Execute DEPOIS do schema.sql já aplicado. Pode ser executado várias vezes.
-- =====================================================================

-- 1) Novas tabelas -----------------------------------------------------
create table if not exists public.packages (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  price numeric(14,2) not null default 0 check (price >= 0),
  duration_min int,
  photos_included int,
  services text,                         -- serviços incluídos / extras
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.team (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  role text not null default 'Fotógrafo' check (role in ('Fotógrafo','Videógrafo','Editor','Assistente')),
  phone text, email text,
  commission_pct numeric(5,2) not null default 0 check (commission_pct between 0 and 100),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.equipment (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  category text,
  serial text,
  condition text not null default 'Bom' check (condition in ('Bom','Em manutenção','Avariado','Fora de uso')),
  holder text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2) Novas colunas (dados existentes ficam intactos) ----------------------
alter table public.clients add column if not exists whatsapp text;
alter table public.clients add column if not exists birth_date date;

alter table public.jobs add column if not exists kind text not null default 'Sessão';
alter table public.jobs add column if not exists end_time time;
alter table public.jobs add column if not exists address text;
alter table public.jobs add column if not exists package_id text references public.packages(id) on delete set null;
alter table public.jobs add column if not exists assignee_id text references public.team(id) on delete set null;
alter table public.jobs add column if not exists post_status text not null default 'Por importar';

-- 3) Regras de validação (aceitam os valores antigos E os novos) ------------
do $$ declare c record; begin
  for c in select conname from pg_constraint
           where conrelid = 'public.jobs'::regclass and contype = 'c'
             and (pg_get_constraintdef(oid) like '%job_type%' or pg_get_constraintdef(oid) like '%status%' or pg_get_constraintdef(oid) like '%kind%')
  loop execute format('alter table public.jobs drop constraint %I', c.conname); end loop;
end $$;

alter table public.jobs add constraint jobs_kind_chk check (kind in ('Sessão','Cobertura'));
alter table public.jobs add constraint jobs_job_type_chk check (job_type in (
  'Casamento','Aniversário','Batizado','Sessão individual','Sessão de casal','Sessão familiar','Fotografia corporativa','Evento','Outro',
  'Retrato','Casal','Família','Maternidade','Recém-nascido','Corporativo','Moda','Produtos','Pré-wedding',
  'Evento corporativo','Conferência','Festa','Outro evento'));
alter table public.jobs add constraint jobs_status_chk check (status in (
  'Pendente','Confirmado','Em execução','Concluído','Cancelado',
  'Novo pedido','Pendente de confirmação','Em preparação','Realizado','Em edição','Entregue'));
alter table public.jobs add constraint jobs_post_status_chk check (post_status in (
  'Por importar','Em seleção','Em edição','Em revisão','Aguardando aprovação','Pronto para entrega','Entregue'));

-- 4) Shot list e cronograma por trabalho ---------------------------------
create table if not exists public.shots (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  job_id text not null references public.jobs(id) on delete cascade,
  description text not null,
  done boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.timeline (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  job_id text not null references public.jobs(id) on delete cascade,
  at_time time,
  description text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists shots_job_idx on public.shots(job_id);
create index if not exists timeline_job_idx on public.timeline(job_id);
create index if not exists jobs_assignee_idx on public.jobs(assignee_id, job_date);

-- 5) updated_at + RLS nas tabelas novas -----------------------------------
do $$ declare t text; begin
  foreach t in array array['packages','team','equipment','shots','timeline'] loop
    execute format('drop trigger if exists trg_%1$s_updated on public.%1$s', t);
    execute format('create trigger trg_%1$s_updated before update on public.%1$s for each row execute function public.set_updated_at()', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "own_rows" on public.%I', t);
    execute format('create policy "own_rows" on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
  end loop;
end $$;
