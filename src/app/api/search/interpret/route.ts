import { createQueryInterpreter } from '@/utils/query-context';

export const runtime = 'nodejs';
const interpret = createQueryInterpreter();

export async function POST(request: Request) {
  const origin = request.headers.get('origin');
  if (!origin || origin !== new URL(request.url).origin) {
    return Response.json({ error: 'Invalid origin' }, { status: 403 });
  }
  if (Number(request.headers.get('content-length')) > 2048) {
    return Response.json({ error: 'Query too long' }, { status: 413 });
  }
  try {
    const body = await request.text();
    if (body.length > 2048) return Response.json({ error: 'Query too long' }, { status: 413 });
    const { query } = JSON.parse(body);
    if (typeof query !== 'string' || query.length > 200) {
      return Response.json({ error: 'Invalid query' }, { status: 400 });
    }
    const result = await interpret(query, process.env.GROQ_API_KEY);
    return Response.json(result, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return Response.json({ error: 'Invalid request' }, { status: 400 });
  }
}
