-- Profile photos are identity data. Keep the bucket private and expose each
-- image only through short-lived signed URLs generated for authenticated users.
update storage.buckets
set public = false
where id = 'profile-avatars';

comment on column public.profiles.avatar_url is
  'Private Storage object path for profile-avatars, or a legacy external URL.';
