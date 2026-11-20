# Funnybone — Context-aware Meme Search

A Columbia University Humor Project semester application for browsing memes,
finding captions, and generating captions for images. The app builds on the
Funnybone/Crackd starter and currently focuses on making meme discovery work with
short, everyday queries.

## Current status

As of November 20, 2026, the current search work is on
`feature/context-search` and has been tested locally and on the Vercel deployment.

Implemented:

- Keyword search across captions in the selected Top 100 feed.
- Topic filters for exams and studying, friends and dating, food and dining,
  jobs and internships, and campus life. Topics are suggested using caption-text
  patterns; a caption can belong to multiple topics.
- Short-query matching with common search introductions removed and predefined
  synonyms, such as `friendship`, `friends`, and `bestie`.
- Groq-assisted query interpretation, with keyword search as a fallback.
- Existing browsing by time period, caption voting, favorites, sharing, image
  uploads, and caption generation workflows.

**Next planned improvement:** search memes by what appears in the image, even
when the caption is unrelated. For example, typing `LeBron James` should retrieve
memes showing him. This is text-to-image retrieval; uploading a reference image
is not required for that planned feature. It is not implemented in the Top 100
search yet.

## How search works

Try a keyword or a short phrase:

- `friendship`
- `captions about friendship`
- `captions about finals`
- `stressed before exams`

Results depend on the captions available in the selected feed and time period.

1. Keyword search responds immediately, normalizing text and matching words and
   predefined synonyms. All meaningful terms in each query must match.
2. After a 600 ms pause in typing, the browser sends the query to
   `POST /api/search/interpret`.
3. The server calls Groq using `openai/gpt-oss-20b`, with low reasoning effort,
   and requests up to four alternative keyword queries in structured JSON.
4. The browser searches the loaded captions using those alternatives. Direct
   query matches stay first; additional matches are appended without duplicates.
   Topic filters still apply.

The UI shows **Understanding your search…**, **Context-assisted search**, or
**Keyword search**. Groq interprets the query; it does not generate search results
or captions in this flow. Only the query and interpretation instructions are sent
to Groq, not the loaded caption collection.

### Search scope and safeguards

- Search currently filters the **loaded Top 100 captions for the selected time
  period**, not the entire database. The feed includes public captions on public
  images with a positive like count, ordered by popularity and recency.
- Context assistance expands keywords. It is not embedding-based semantic search
  and does not inspect image pixels or image metadata in this search interface.
- Negative queries are not broadened with AI alternatives. The keyword matcher
  does not implement logical exclusions such as “everything except exams.”
- Missing API keys, invalid responses, timeouts, and provider errors fall back to
  keyword search. A missing key means no request is sent to Groq.
- Interpretations are cached for 10 minutes, with up to 200 cached entries and
  concurrent identical requests sharing one provider call.
- Provider calls have a 5-second timeout and instance-local caps of 10 calls per
  minute and 100 calls per day. Rate-limit errors trigger a cooldown.
- These caches and caps are in memory. They reset on restart and are not shared
  across Vercel instances, so they are not an account-wide usage or billing cap.
  Keep the Groq account on its free plan if paid usage is not desired.

The common-use image picker under `/new` has a separate search over image
metadata and database-backed image categories. It is distinct from the Top 100
caption search described above.

## Technology

- Next.js 16 App Router, React 19, and TypeScript.
- Tailwind CSS, Radix UI components, and Framer Motion.
- Supabase for authentication and application data.
- Groq for optional server-side query interpretation.
- A separate course caption API for image uploads and caption generation.
- Vercel for the current deployment.

## Local development

Use **Node.js 24.x**. A compatible Supabase schema and data are required; creating
an empty Supabase project alone is not enough. See [course setup](COURSE_SETUP.md)
for the starter's database and authentication requirements.

From the repository root:

```bash
nvm install
nvm use
npm ci
cp .env.example .env.local
```

Copy the environment file only on first setup; preserve an existing `.env.local`.
Configure its values, then start the app:

```bash
npm run dev
```

Open [localhost:3000](http://localhost:3000). Restart the development server after
changing environment variables.

### Environment variables

Use [.env.example](.env.example) as the template:

- `NEXT_PUBLIC_SUPABASE_URL`: the compatible Supabase project's URL.
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: its public anon key. Authenticated operations
  use the signed-in user's session; no Supabase service-role key is required.
- `NEXT_PUBLIC_BASE_URL`: the app's base URL, such as `http://localhost:3000`.
- `NEXT_PUBLIC_BRAND_NAME` and `NEXT_PUBLIC_ENVIRONMENT`: branding and environment
  settings.
- `NEXT_PUBLIC_API_BASE_URL`: the course-approved external caption API endpoint,
  needed for uploads and caption generation.
- `NEXT_PUBLIC_GOOGLE_CLIENT_ID`: configure if required by the supported Google
  sign-in setup, along with the appropriate authentication redirect URLs.
- `GROQ_API_KEY`: optional server-side key enabling context-assisted search.
  Without it, keyword and topic filtering remain available.

Never commit `.env.local` or real credentials. Do not prefix `GROQ_API_KEY` with
`NEXT_PUBLIC_`; it must remain on the server.

## Vercel deployment

1. Connect the GitHub repository to the Vercel project and deploy the intended
   branch. Use Node.js 24.x.
2. Configure the required environment variables in the Vercel project settings.
   The `.env.local` file on a laptop is not uploaded by pushing this repository.
3. Add `GROQ_API_KEY` to **Preview** for feature-branch previews and to
   **Production** for production deployments that need context-assisted search.
4. Set the app base URL and authentication redirects for the deployment.
5. Redeploy after changing environment variables; existing deployments do not
   receive the new values automatically.

If every query stays on **Keyword search** and Groq shows no recent requests,
first check that the deployed environment has `GROQ_API_KEY` and that a new
deployment was created after adding it. Also check the browser request to
`/api/search/interpret` and the Vercel function logs. Cached interpretations can
avoid provider calls for repeated queries within 10 minutes.

The repository also retains `sst.config.ts` and a secret-sync script from the
AWS setup. They are separate from the current Vercel workflow. There are no
`deploy:staging` or `deploy:production` npm scripts in the current package.

## Checks

```bash
npm run lint
npm test
npm run build
```

- Lint checks code quality and formatting, including a 100-character line limit.
- Tests use Node's built-in runner and cover search behavior, Groq response
  handling, caching, fallback behavior, and caption-generation workflows.
- The build checks the production bundle and TypeScript compilation.

GitHub Actions runs lint and build on pushes and pull requests. Existing lint
warnings are non-blocking; lint errors fail the check. Groq tests use mocked
responses and do not require a real API key.

## Relevant files

- [Search UI](src/components/popular-captions-page-client.tsx): query input,
  delayed context requests, status messages, topic filters, and caption results.
- [Caption matching](src/utils/caption-search.ts): normalization, synonym
  matching, ranking, and merging contextual results.
- [Topic definitions](src/utils/caption-topics.ts): caption-text topic patterns.
- [Interpretation endpoint](src/app/api/search/interpret/route.ts): server-side
  request validation and access to `GROQ_API_KEY`.
- [Groq interpreter](src/utils/query-context.ts): model request, output validation,
  caching, usage caps, and fallback handling.
- [Feed query](src/app/actions/captions/fetch-popular-captions-action.ts): public
  Top 100 data and time-period filtering.
- [Image picker](src/components/generate-roasts.tsx): common-use images, personal
  image library, uploads, and generation entry points.
- [Caption job documentation](docs/caption-jobs.md): background generation,
  polling, resuming jobs, and saved results.
- [Database types](src/types/supabase.ts): generated Supabase schema types.
