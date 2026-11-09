// Lightweight topic suggestions from caption text; captions may match multiple topics.
export const captionTopics = [
  {
    id: "academics",
    label: "Exams & studying",
    pattern: new RegExp(
      "\\b(exams?|finals?|midterms?|stud(y|ies|ying)|homework|grades?|" +
      "gradescope|syllabus|professors?|lectures?|assignments?|gpa|" +
      "course(s|work)?|essays?|quizzes|quiz)\\b",
      "i",
    ),
  },
  {
    id: "relationships",
    label: "Friends & dating",
    pattern: new RegExp(
      "\\b(friends?|friendship|besties?|best\\s+friend|dating|dates?|" +
      "crush(es)?|boyfriends?|girlfriends?|relationships?|breakups?|" +
      "roommates?|texts?|texting)\\b",
      "i",
    ),
  },
  {
    id: "food",
    label: "Food & dining",
    pattern: new RegExp(
      "\\b(food|dining|meals?|lunch|dinner|breakfast|snacks?|coffee|" +
      "pizzas?|restaurants?|hungry|eat(s|ing)?|cafeterias?)\\b",
      "i",
    ),
  },
  {
    id: "career",
    label: "Jobs & internships",
    pattern: new RegExp(
      "\\b(jobs?|internships?|interns?|interviews?|resumes?|recruit(ing|" +
      "ers?)?|careers?|linkedin|offers?|applications?)\\b",
      "i",
    ),
  },
  {
    id: "campus",
    label: "Campus life",
    pattern: new RegExp(
      "\\b(campus|columbia|barnard|dorms?|libraries|library|butler|" +
      "low\\s+steps|college|universit(y|ies)|student(s|\\s+life)?|clubs?|" +
      "parties|party)\\b",
      "i",
    ),
  },
] as const;

export type CaptionTopic = "all" | typeof captionTopics[number]["id"];

export function matchesCaptionTopic(content: string, topic: CaptionTopic): boolean {
  return topic === "all" || Boolean(
    captionTopics.find(item => item.id === topic)?.pattern.test(content),
  );
}
