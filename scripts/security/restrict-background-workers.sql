-- These background procedures use COMMIT, so PostgreSQL does not allow a
-- procedure-level SET search_path clause. Their bodies qualify application objects.
-- Restrict invocation instead; cron continues running as the owning database role.
REVOKE ALL ON PROCEDURE funnystudy_notifications.deliver_sms() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON PROCEDURE funnystudy_notifications.deliver_voice() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON PROCEDURE funnystudy_notifications.deliver_sms() TO service_role;
GRANT EXECUTE ON PROCEDURE funnystudy_notifications.deliver_voice() TO service_role;
