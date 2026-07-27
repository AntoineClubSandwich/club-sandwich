alter table public.concerts
  add column if not exists promoter_contact_name text,
  add column if not exists promoter_contact_phone text,
  add column if not exists promoter_contact_email text,
  add column if not exists catering_contact_name text,
  add column if not exists catering_contact_phone text,
  add column if not exists catering_contact_email text;

grant update (
  promoter_contact_name,
  promoter_contact_phone,
  promoter_contact_email,
  catering_contact_name,
  catering_contact_phone,
  catering_contact_email
) on public.concerts to authenticated;
