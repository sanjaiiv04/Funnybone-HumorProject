-- Keep extension objects out of the API schema. Existing vector column types
-- retain their OIDs; match_community_contexts already includes extensions in its path.
ALTER EXTENSION vector SET SCHEMA extensions;
REVOKE CREATE ON SCHEMA extensions FROM PUBLIC, anon, authenticated;
