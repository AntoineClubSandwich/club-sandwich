alter table public.concert_volunteers
  add constraint concert_volunteers_attendance_requires_confirmation
  check (
    status <> 'selected'::public.concert_volunteer_status
    or confirmation_status =
      'confirmed'::public.volunteer_confirmation_status
    or attendance_status =
      'pending'::public.volunteer_attendance_status
  );
