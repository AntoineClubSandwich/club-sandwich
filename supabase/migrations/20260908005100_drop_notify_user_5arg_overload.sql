-- 20260908005000 added a 6th (defaulted) parameter to private.notify_user
-- via create or replace, but a differing arg count creates a NEW overload
-- rather than replacing the function - the original 5-arg version was
-- still live, making every 5-arg call ("select private.notify_user(...)"
-- with 5 args) ambiguous between "the old function" and "the new one
-- with its 6th arg defaulted" (42725: function ... is not unique).
-- Every call site in this codebase passes exactly 5 args (the send_email
-- flag isn't used by any flow yet, that's the next phase), so this drops
-- the now-redundant original overload, leaving the 6-arg one as the only
-- resolution for a 5-arg call.

drop function private.notify_user(uuid, uuid, text, text, text);
