BEGIN;
-- Fixtures are generated for this transaction and always rolled back.
DO $$
DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); img uuid:=gen_random_uuid(); pub uuid:=gen_random_uuid(); priv uuid:=gen_random_uuid();
BEGIN
 PERFORM set_config('rls_test.a',a::text,true); PERFORM set_config('rls_test.b',b::text,true);
 PERFORM set_config('rls_test.image',img::text,true); PERFORM set_config('rls_test.public',pub::text,true);
 PERFORM set_config('rls_test.private',priv::text,true);
 INSERT INTO auth.users(id) VALUES(a),(b);
 INSERT INTO public.images(id,profile_id,url,is_public,is_common_use,created_by_user_id,modified_by_user_id)
 VALUES(img,b,'https://example.invalid/rls-test.png',true,false,b,b);
 INSERT INTO public.captions(id,profile_id,image_id,content,is_public,created_by_user_id,modified_by_user_id)
 VALUES(pub,b,img,'RLS test public',true,b,b),(priv,b,img,'RLS test private',false,b,b);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',false)::text,true);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE a uuid:=current_setting('rls_test.a')::uuid; b uuid:=current_setting('rls_test.b')::uuid;
 pub uuid:=current_setting('rls_test.public')::uuid; priv uuid:=current_setting('rls_test.private')::uuid; n integer;
BEGIN
 IF EXISTS(SELECT 1 FROM public.profiles WHERE id=b) THEN RAISE EXCEPTION 'Other profile exposed'; END IF;
 UPDATE public.profiles SET first_name='RLS test' WHERE id=b;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>0 THEN RAISE EXCEPTION 'Other profile writable'; END IF;
 UPDATE public.profiles SET first_name='RLS test' WHERE id=a;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'Own profile editing broken'; END IF;
 BEGIN
   UPDATE public.profiles SET is_superadmin=true WHERE id=a;
   RAISE EXCEPTION 'Privilege escalation allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   UPDATE public.profiles SET is_matrix_admin=true WHERE id=a;
   RAISE EXCEPTION 'Matrix privilege escalation allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF EXISTS(SELECT 1 FROM public.captions WHERE id=priv) OR public.can_access_caption(priv) THEN
   RAISE EXCEPTION 'Private caption exposed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.captions WHERE id=pub) THEN RAISE EXCEPTION 'Public caption unreadable'; END IF;
 INSERT INTO public.caption_votes(profile_id,caption_id,vote_value) VALUES(a,pub,1);
 IF (SELECT like_count FROM public.captions WHERE id=pub)<>1 THEN RAISE EXCEPTION 'Vote counter failed'; END IF;
 BEGIN
   INSERT INTO public.caption_votes(profile_id,caption_id,vote_value) VALUES(a,pub,1);
   RAISE EXCEPTION 'Duplicate vote allowed';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN
   INSERT INTO public.caption_votes(profile_id,caption_id,vote_value) VALUES(b,pub,1);
   RAISE EXCEPTION 'Forged vote allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   INSERT INTO public.caption_votes(profile_id,caption_id,vote_value) VALUES(a,priv,1);
   RAISE EXCEPTION 'Private caption vote allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   UPDATE public.captions SET like_count=999 WHERE id=pub;
   RAISE EXCEPTION 'Counter forgery allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.caption_saves(profile_id,caption_id) VALUES(a,pub);
 IF NOT EXISTS(SELECT 1 FROM public.caption_saves WHERE profile_id=a AND caption_id=pub) THEN RAISE EXCEPTION 'Save broken'; END IF;
 DELETE FROM public.caption_votes WHERE profile_id=a AND caption_id=pub;
 IF (SELECT like_count FROM public.captions WHERE id=pub)<>0 THEN RAISE EXCEPTION 'Unvote counter failed'; END IF;
END $$;
SET LOCAL ROLE anon;
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.profiles) THEN RAISE EXCEPTION 'Anonymous profiles exposed'; END IF;
 IF EXISTS(SELECT 1 FROM public.caption_votes) THEN RAISE EXCEPTION 'Anonymous votes exposed'; END IF;
 IF EXISTS(SELECT 1 FROM public.caption_saves) THEN RAISE EXCEPTION 'Anonymous saves exposed'; END IF;
 IF EXISTS(SELECT 1 FROM public.bug_reports) THEN RAISE EXCEPTION 'Anonymous reports exposed'; END IF;
 IF EXISTS(SELECT 1 FROM public.whitelist_email_addresses) THEN RAISE EXCEPTION 'Anonymous whitelist exposed'; END IF;
 PERFORM 1 FROM public.allowed_signup_domains LIMIT 1;
END $$;
RESET ROLE;
SELECT 'PASS: cross-user isolation, privilege escalation, private captions, vote/unvote counters, duplicate/forged votes, saves, anonymous access' AS result;
ROLLBACK;
