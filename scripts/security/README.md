# Database access hardening

Applied to `funnybone-semester-project` (`rrjajrvambenjcluroaj`) on November 10, 2026.
The SQL files are reviewable copies of the three hosted migrations, in this order:

1. `harden_exposed_tables_and_rls_access` — `harden-database.sql`
2. `isolate_vector_extension_from_public_api` — `isolate-vector-extension.sql`
3. `restrict_notification_background_worker_execution` — `restrict-background-workers.sql`

These scripts are not idempotent. Do not reapply them to this project. The hosted
migration history is authoritative. No service-role key was added to the app.

All 87 public tables have RLS enabled. Four views now use security invoker.
Personal votes, saves, and profile mappings require ownership. Unconfigured
internal tables default to superadmin access; six worker/hash tables retain
deny-by-default RLS without client policies. Existing notification configuration
tables also intentionally have no client policies.

Profile ownership is enforced even alongside existing permissive policies.
Privilege fields cannot be changed by ordinary users. Private-caption checks
include caption visibility, not just image visibility. Votes must be +/-1 and
unique per user/caption, and cannot be updated to target another caption.
The narrow, non-RPC vote trigger maintains counters under its owner's privileges;
clients cannot directly update counters or generated scores. Public schema CREATE
permission is revoked, function paths are pinned, and trigger RPC access is revoked.

## Verification

`verify-rls.sql` creates temporary user/content fixtures in a transaction and rolls
them back. It passed live checks for cross-user profile isolation, privilege
escalation, private captions, public-caption reads, vote/unvote counter updates,
duplicate/forged votes, saves, and anonymous access. Identity sequences can advance
during rolled-back tests. Run with a trusted database administrator connection.

Additional catalog checks confirmed no public table without RLS, vector in the
extensions schema, and no anon/authenticated EXECUTE on either notification worker.
`npm run build` and `npx tsc --noEmit` passed. The build retains the existing Next.js
middleware deprecation warning. No real-user browser session was available for an
end-to-end sign-in/upload/generation test. Internal tooling previously relying on
unrestricted authenticated access now requires a superadmin or an explicitly
reviewed policy.

## Remaining security advisories

The post-change security advisor reports zero ERROR findings. Remaining notices:

- Twelve INFO notices for RLS without policies: intentionally deny client access;
  adding permissive policies to silence these would reduce security.
- Two mutable-search-path warnings on notification worker procedures. These use
  COMMIT, which is incompatible with a procedure-level SET clause. Their application
  objects are schema-qualified, and execution is revoked from public client roles.
- Fourteen authenticated security-definer function warnings: access helpers needed
  by RLS, superadmin-checked job RPCs, and the signature-verified webhook. Their
  elevated privilege is intentional; do not broadly grant execution to anon.
- One anonymous security-definer warning: `receive_telnyx_phone_event` must accept
  incoming provider webhooks. Its body validates signature, timestamp, provider,
  destination, and replay identity before changing notification preferences.
- Leaked-password protection is disabled. This is still unresolved: the connector
  has no Auth configuration update tool, and dashboard navigation returned 404.
  Enable it in Supabase Authentication password security settings if the project
  plan supports it. See https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.

This work addresses the inspected database access paths; a clean error list is
not proof that the entire application has no vulnerabilities. Public Storage
images remain public under the existing product configuration.
