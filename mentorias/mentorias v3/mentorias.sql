-- SHUTTERLITE | MENTORIAS ONLINE
create extension if not exists pgcrypto;

do $$ begin create type public.mentoria_application_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;
do $$ begin create type public.mentoria_user_role as enum ('student','admin');
exception when duplicate_object then null; end $$;
do $$ begin create type public.mentoria_user_status as enum ('active','blocked');
exception when duplicate_object then null; end $$;

create table if not exists public.mentoria_applications(
 id uuid primary key default gen_random_uuid(), full_name text not null, email text not null,
 phone text not null, country text not null, city text not null,
 interest_area text not null check(interest_area in ('Fotografia','Vídeo','Importações e comércio','Tráfego pago / Marketing Digital')),
 experience_level text not null check(experience_level in ('Iniciante','Intermédio','Avançado','Profissional')),
 goals text not null, experience text not null, how_found_us text, additional_information text,
 status public.mentoria_application_status not null default 'pending',
 reviewed_by uuid references auth.users(id), reviewed_at timestamptz, admin_notes text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index if not exists mentoria_applications_pending_email
on public.mentoria_applications(lower(email)) where status='pending';

create table if not exists public.mentoria_profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null, phone text, country text, city text,
 role public.mentoria_user_role not null default 'student',
 status public.mentoria_user_status not null default 'active',
 application_id uuid references public.mentoria_applications(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create or replace function public.mentoria_is_admin() returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.mentoria_profiles
 where id=auth.uid() and role='admin' and status='active');
$$;
revoke all on function public.mentoria_is_admin() from public;
grant execute on function public.mentoria_is_admin() to authenticated;

create or replace function public.mentoria_submit_application(
 p_full_name text,p_email text,p_phone text,p_country text,p_city text,
 p_interest_area text,p_experience_level text,p_goals text,p_experience text,
 p_how_found_us text default null,p_additional_information text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_email text:=lower(trim(p_email));
begin
 if length(trim(p_full_name))<3 then raise exception 'Nome inválido'; end if;
 if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Email inválido'; end if;
 if exists(select 1 from public.mentoria_applications where lower(email)=v_email and status='pending')
 then raise exception 'Já existe uma candidatura pendente para este email'; end if;
 insert into public.mentoria_applications(full_name,email,phone,country,city,interest_area,experience_level,goals,experience,how_found_us,additional_information,status)
 values(trim(p_full_name),v_email,trim(p_phone),trim(p_country),trim(p_city),p_interest_area,p_experience_level,trim(p_goals),trim(p_experience),nullif(trim(p_how_found_us),''),nullif(trim(p_additional_information),''),'pending')
 returning id into v_id; return v_id;
end $$;
revoke all on function public.mentoria_submit_application(text,text,text,text,text,text,text,text,text,text,text) from public;
grant execute on function public.mentoria_submit_application(text,text,text,text,text,text,text,text,text,text,text) to anon,authenticated;

create or replace function public.mentoria_review_application(
 p_application_id uuid,p_status public.mentoria_application_status,p_admin_notes text default null)
returns public.mentoria_applications language plpgsql security definer set search_path=public as $$
declare v_app public.mentoria_applications;
begin
 if not public.mentoria_is_admin() then raise exception 'Acesso negado'; end if;
 if p_status not in('approved','rejected') then raise exception 'Estado inválido'; end if;
 update public.mentoria_applications set status=p_status,reviewed_by=auth.uid(),reviewed_at=now(),admin_notes=nullif(trim(p_admin_notes),'')
 where id=p_application_id returning * into v_app;
 if v_app.id is null then raise exception 'Candidatura não encontrada'; end if;
 return v_app;
end $$;
revoke all on function public.mentoria_review_application(uuid,public.mentoria_application_status,text) from public;
grant execute on function public.mentoria_review_application(uuid,public.mentoria_application_status,text) to authenticated;

create or replace function public.mentoria_activate_student(p_application_id uuid,p_user_id uuid)
returns public.mentoria_profiles language plpgsql security definer set search_path=public as $$
declare v_app public.mentoria_applications; v_profile public.mentoria_profiles;
begin
 if not public.mentoria_is_admin() then raise exception 'Acesso negado'; end if;
 select * into v_app from public.mentoria_applications where id=p_application_id and status='approved';
 if v_app.id is null then raise exception 'A candidatura não está aprovada'; end if;
 insert into public.mentoria_profiles(id,full_name,phone,country,city,role,status,application_id)
 values(p_user_id,v_app.full_name,v_app.phone,v_app.country,v_app.city,'student','active',v_app.id)
 on conflict(id) do update set full_name=excluded.full_name,phone=excluded.phone,country=excluded.country,city=excluded.city,role='student',status='active',application_id=excluded.application_id,updated_at=now()
 returning * into v_profile; return v_profile;
end $$;
revoke all on function public.mentoria_activate_student(uuid,uuid) from public;
grant execute on function public.mentoria_activate_student(uuid,uuid) to authenticated;

alter table public.mentoria_applications enable row level security;
alter table public.mentoria_profiles enable row level security;

drop policy if exists "mentoria applications admin select" on public.mentoria_applications;
create policy "mentoria applications admin select" on public.mentoria_applications for select to authenticated using(public.mentoria_is_admin());
drop policy if exists "mentoria applications admin update" on public.mentoria_applications;
create policy "mentoria applications admin update" on public.mentoria_applications for update to authenticated using(public.mentoria_is_admin()) with check(public.mentoria_is_admin());

drop policy if exists "mentoria profiles own select" on public.mentoria_profiles;
create policy "mentoria profiles own select" on public.mentoria_profiles for select to authenticated using(id=auth.uid() or public.mentoria_is_admin());
drop policy if exists "mentoria profiles admin update" on public.mentoria_profiles;
create policy "mentoria profiles admin update" on public.mentoria_profiles for update to authenticated using(public.mentoria_is_admin()) with check(public.mentoria_is_admin());
drop policy if exists "mentoria profiles admin delete" on public.mentoria_profiles;
create policy "mentoria profiles admin delete" on public.mentoria_profiles for delete to authenticated using(public.mentoria_is_admin());

-- Após criar a conta administrativa no Supabase Auth:
-- insert into public.mentoria_profiles(id,full_name,role,status)
-- values('UUID_AUTH_ADMIN','Administrador','admin','active');
