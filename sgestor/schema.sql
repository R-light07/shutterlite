-- =====================================================================
-- Obturador · Estrutura da base de dados (Supabase / PostgreSQL)
-- Cole no Supabase: SQL Editor > New query > Run
-- Cada utilizador autenticado só vê e altera os seus próprios dados (RLS).
-- =====================================================================

create table if not exists public.clients (
  id         text primary key default gen_random_uuid()::text,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name       text not null,
  phone      text,
  email      text,
  address    text,
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id            text primary key default gen_random_uuid()::text,
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id     text references public.clients(id) on delete restrict,
  title         text not null,
  job_type      text not null default 'Outro'
                check (job_type in ('Casamento','Aniversário','Batizado','Sessão individual','Sessão de casal','Sessão familiar','Fotografia corporativa','Evento','Outro')),
  job_date      date not null,
  job_time      time,
  location      text,
  description   text,
  agreed_value  numeric(14,2) not null default 0 check (agreed_value >= 0),
  status        text not null default 'Pendente'
                check (status in ('Pendente','Confirmado','Em execução','Concluído','Cancelado')),
  delivery_date date,
  documents     jsonb not null default '[]'::jsonb,   -- anexos: [{name, data}]
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.expenses (
  id             text primary key default gen_random_uuid()::text,
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  job_id         text not null references public.jobs(id) on delete cascade,
  description    text,
  category       text not null
                 check (category in ('Transporte e combustível','Alimentação','Alojamento','Aluguer de equipamentos','Assistentes e colaboradores','Edição e tratamento','Impressões e álbuns','Decoração e cenografia','Marketing e publicidade','Outras')),
  amount         numeric(14,2) not null check (amount >= 0),
  expense_date   date not null default current_date,
  payment_method text not null default 'Dinheiro'
                 check (payment_method in ('Dinheiro','Transferência bancária','M-Pesa','e-Mola','Outro')),
  receipt        jsonb,                                -- comprovativo: {name, data}
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.payments (
  id           text primary key default gen_random_uuid()::text,
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  job_id       text not null references public.jobs(id) on delete cascade,
  payment_type text not null default 'Parcial' check (payment_type in ('Sinal','Parcial','Final')),
  amount       numeric(14,2) not null check (amount > 0),
  payment_date date not null default current_date,
  method       text not null default 'Dinheiro'
               check (method in ('Dinheiro','Transferência bancária','M-Pesa','e-Mola','Outro')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Índices
create index if not exists jobs_user_date_idx   on public.jobs(user_id, job_date);
create index if not exists jobs_client_idx      on public.jobs(client_id);
create index if not exists expenses_job_idx     on public.expenses(job_id);
create index if not exists payments_job_idx     on public.payments(job_id);

-- updated_at automático
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;

do $$ declare t text; begin
  foreach t in array array['clients','jobs','expenses','payments'] loop
    execute format('drop trigger if exists trg_%1$s_updated on public.%1$s', t);
    execute format('create trigger trg_%1$s_updated before update on public.%1$s for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- Segurança ao nível da linha (RLS): cada utilizador só acede aos seus dados
do $$ declare t text; begin
  foreach t in array array['clients','jobs','expenses','payments'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "own_rows" on public.%I', t);
    execute format('create policy "own_rows" on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
  end loop;
end $$;

-- Vista financeira por trabalho (lucro, margem, recebido, saldo)
create or replace view public.job_financials with (security_invoker = true) as
select
  j.id as job_id, j.user_id, j.title, j.client_id, j.job_type, j.job_date, j.status,
  case when j.status = 'Cancelado' then 0 else j.agreed_value end                  as revenue,
  coalesce(e.total, 0)                                                              as total_expenses,
  (case when j.status = 'Cancelado' then 0 else j.agreed_value end) - coalesce(e.total, 0) as net_profit,
  case when j.status = 'Cancelado' or j.agreed_value = 0 then 0
       else round(((j.agreed_value - coalesce(e.total,0)) / j.agreed_value) * 100, 2) end as margin_pct,
  coalesce(p.total, 0)                                                              as received,
  greatest(j.agreed_value - coalesce(p.total, 0), 0)                                as balance_due,
  coalesce(p.total, 0) - coalesce(e.total, 0)                                       as cash_available,
  case when coalesce(p.total,0) <= 0 then 'Não pago'
       when coalesce(p.total,0) >= j.agreed_value then 'Totalmente pago'
       else 'Parcialmente pago' end                                                 as payment_status
from public.jobs j
left join (select job_id, sum(amount) total from public.expenses group by job_id) e on e.job_id = j.id
left join (select job_id, sum(amount) total from public.payments group by job_id) p on p.job_id = j.id;
