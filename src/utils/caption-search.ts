// Small, explicit synonym groups keep short queries predictable without an AI service.
const synonyms = [
  ['friendship', 'friendships', 'friend', 'friends', 'bestie', 'besties', 'bff'],
  ['exam', 'exams', 'final', 'finals', 'midterm', 'midterms'],
  ['study', 'studies', 'studying'],
  ['job', 'jobs', 'career', 'careers'],
  ['internship', 'internships', 'intern', 'interns'],
  ['library', 'libraries'],
  ['roommate', 'roommates'],
  ['relationship', 'relationships', 'dating'],
] as const;

function normalize(text: string): string {
  return text.normalize('NFKC').toLowerCase().replace(/[’']/g, '')
    .replace(/[^\p{L}\p{N}\s]/gu, ' ').replace(/\s+/g, ' ').trim();
}

function searchTerms(query: string): string[] {
  // Strip only introductory search wording. Keep negation and descriptive words.
  const introduction = new RegExp(
    '^(?:please\\s+)?(?:(?:can you\\s+)?(?:show|give|find|get)(?:\\s+me)?\\s+' +
    '|(?:i want|i need)\\s+)?(?:the\\s+|some\\s+)?(?:memes?|captions?)' +
    '(?:\\s+(?:about|on|with|related to))?(?:\\s+the)?(?:\\s+|$)', 'u',
  );
  const subject = normalize(query).replace(introduction, '');
  const connectors = new Set(['and', 'about', 'with', 'at', 'the', 'a', 'an']);
  return [...new Set(subject.split(' ').filter(word => word && !connectors.has(word)))];
}

/** Search the supplied feed; ties retain its existing popularity/date order. */
export function searchCaptions<T extends { content: string }>(captions: T[], query: string): T[] {
  if (!query.trim()) return captions;
  const terms = searchTerms(query);
  if (!terms.length) return [];
  return captions.map((caption, index) => {
    const normalized = normalize(caption.content);
    const words = new Set(normalized.split(' '));
    let score = 0;
    for (const term of terms) {
      if (words.has(term)) {
        score += 3;
      } else {
        const group = synonyms.find(items => (items as readonly string[]).includes(term));
        if (!group?.some(word => words.has(word))) return { caption, index, score: 0 };
        score += 1;
      }
    }
    if (normalized.includes(terms.join(' '))) score += 2;
    return { caption, index, score };
  }).filter(result => result.score > 0)
    .sort((a, b) => b.score - a.score || a.index - b.index)
    .map(result => result.caption);
}

/** Keep direct matches first; append distinct matches from equivalent query rewrites. */
export function searchCaptionsWithContext<T extends { content: string }>(
  captions: T[], query: string, alternatives: string[] = [],
): T[] {
  const direct = searchCaptions(captions, query);
  // Do not broaden exclusions with positive alternatives.
  if (!query.trim() || /\b(no|not|without|except|exclude|excluding)\b/i.test(query)) return direct;
  const seen = new Set(direct);
  const results = [...direct];
  for (const alternative of alternatives.slice(0, 4)) {
    for (const caption of searchCaptions(captions, alternative)) {
      if (!seen.has(caption)) { seen.add(caption); results.push(caption); }
    }
  }
  return results;
}
