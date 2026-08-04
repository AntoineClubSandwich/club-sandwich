update public.concert_volunteers
set
  confirmation_status =
    'pending'::public.volunteer_confirmation_status,
  confirmation_responded_at = null
from public.concerts concert
where concert_volunteers.status =
    'selected'::public.concert_volunteer_status
  and concert.id = concert_volunteers.concert_id
  and concert.concert_date >= current_date
  and concert.maraude_status not in (
    'completed'::public.maraude_status,
    'cancelled'::public.maraude_status
  )
  and concert_volunteers.attendance_status =
    'pending'::public.volunteer_attendance_status
  and concert_volunteers.confirmation_status =
    'confirmed'::public.volunteer_confirmation_status
  and concert_volunteers.confirmation_requested_at =
    concert_volunteers.confirmation_responded_at;
