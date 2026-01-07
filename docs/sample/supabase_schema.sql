-- Patto / Supabase schema (MVP)
-- 1) Supabase SQL editor で実行してください。

-- gen_random_uuid() 用
create extension if not exists pgcrypto;

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  content text not null default '',
  is_deleted boolean not null default false,
  local_updated_at timestamptz not null,
  server_updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),

  sync_version integer not null default 1,
  client_id text
);

create index if not exists idx_notes_user_id on public.notes(user_id);
create index if not exists idx_notes_server_updated_at on public.notes(server_updated_at);
create index if not exists idx_notes_user_server_updated_at on public.notes(user_id, server_updated_at);

-- server_updated_at はサーバー時刻で更新（端末時計ズレ対策）
create or replace function public.set_server_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.server_updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_set_server_updated_at on public.notes;
create trigger trg_set_server_updated_at
before insert or update on public.notes
for each row execute function public.set_server_updated_at();

-- RLS
alter table public.notes enable row level security;

drop policy if exists "Users can view own notes" on public.notes;
create policy "Users can view own notes"
  on public.notes for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own notes" on public.notes;
create policy "Users can insert own notes"
  on public.notes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own notes" on public.notes;
create policy "Users can update own notes"
  on public.notes for update
  using (auth.uid() = user_id);

drop policy if exists "Users can delete own notes" on public.notes;
create policy "Users can delete own notes"
  on public.notes for delete
  using (auth.uid() = user_id);

-- 削除済みは14日経過後に完全削除（パージ）するため、DELETEを許可する。

-- Realtime（必要なら）
do $$
begin
  alter publication supabase_realtime add table public.notes;
exception
  when duplicate_object then null;
end $$;
