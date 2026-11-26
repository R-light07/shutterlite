-- Correção: usa a tabela "team_members" (a tabela "team" já existia no teu Supabase
-- com outra estrutura). Pode ser executado várias vezes. Não apaga dados.

create table if not exists public.team_members (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  role text not null default 'Fotógrafo' check (role in ('Fotógrafo','Videógrafo','Droneman','Editor','Assistente')),
  phone text, email text,
  commission_pct numeric(5,2) not null default 0 check (commission_pct between 0 and 100),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.team_members enable row level security;
drop policy if exists "own_rows" on public.team_members;
create policy "own_rows" on public.team_members for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop trigger if exists trg_team_members_updated on public.team_members;
create trigger trg_team_members_updated before update on public.team_members
  for each row execute function public.set_updated_at();

-- Reaponta o responsável dos trabalhos para a tabela correta
update public.jobs set assignee_id = null
  where assignee_id is not null and assignee_id not in (select id from public.team_members);
alter table public.jobs drop constraint if exists jobs_assignee_id_fkey;
alter table public.jobs add constraint jobs_assignee_id_fkey
  foreign key (assignee_id) references public.team_members(id) on delete set null;
