# Supabase keep-alive

The `Supabase Keep Alive` GitHub Actions workflow makes a small read through the
Supabase Data API at 12:00 UTC every third day of the month, matching the
existing HumorProject workflow. It can also be started manually. It uses the
existing public key and row-level security; it does not modify records, call the
caption-generation API, or require a service-role key.

## Enable it

1. In this GitHub repository, open **Settings → Secrets and variables → Actions**.
2. Add these **repository secrets** from your local `.env.local`:
   - `SUPABASE_URL`: the value of `NEXT_PUBLIC_SUPABASE_URL`.
   - `SUPABASE_ANON_KEY`: the value of `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
     The current public publishable key is supported too.
3. Commit the workflow to the repository's **default branch** (currently
   `baseline`). A copy on a feature branch alone does not activate its schedule.
4. Open **Actions → Supabase Keep Alive → Run workflow** and confirm the read
   returns HTTP 200. If the project is already paused, resume it in Supabase first.

The job needs no checkout, npm install, database password, or GitHub write
permissions. It discards the response body and fails on HTTP errors, missing
secrets, and network failures. Transient errors are retried within a short timeout.

## Scheduling limits

Reference workflow: https://github.com/sanjaiiv04/HumorProject/blob/main/.github/workflows/keep-alive.yml

This is a best-effort activity check, not a guarantee against pausing. Supabase
may pause Free Plan projects with low activity over seven days. GitHub schedules
can be delayed or dropped, and public-repository schedules are disabled after
60 days without repository activity. Check Actions periodically and re-enable
the workflow if necessary.

References:
- https://supabase.com/docs/guides/deployment/going-into-prod
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule
