-- Reviewed against funnybone-semester-project (rrjajrvambenjcluroaj).
-- Enable existing policies; tables without an established client access model default to admin only.
REVOKE CREATE ON SCHEMA public FROM PUBLIC, anon, authenticated;
-- All statements are applied together by the hosted migration tool.
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.relname);
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t.relname) THEN
      -- Queues and content hashes intentionally remain inaccessible to client roles.
      IF t.relname NOT IN ('caption_generation_jobs','caption_generation_tasks','image_content_assets',
        'image_content_hashes','quick_study_import_jobs','quick_study_import_tasks') THEN
        EXECUTE format('CREATE POLICY hardened_admin_access ON public.%I FOR ALL TO authenticated
          USING ((SELECT public.is_superadmin(auth.uid())))
          WITH CHECK ((SELECT public.is_superadmin(auth.uid())))',t.relname);
      END IF;
    END IF;
  END LOOP;
END $$;

-- One vote per person/caption prevents repeated inserts inflating scores.
CREATE UNIQUE INDEX hardened_caption_votes_owner_caption ON public.caption_votes(profile_id,caption_id);
ALTER TABLE public.caption_votes ADD CONSTRAINT hardened_vote_value CHECK (vote_value IN (-1,1)) NOT VALID;
CREATE POLICY hardened_caption_insert_counter ON public.captions AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (coalesce(like_count,0)=0 AND is_featured IS NOT TRUE);

-- Public signup configuration and authenticated reference lists.
CREATE POLICY hardened_signup_domains_read ON public.allowed_signup_domains FOR SELECT TO anon, authenticated USING (true);
DO $$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['dorms','universities','university_majors','university_major_mappings',
    'humor_flavors','humor_flavor_mix','humor_themes','humor_flavor_theme_mappings',
    'share_to_destinations','term_types','terms']
  LOOP
    EXECUTE format('CREATE POLICY hardened_reference_read ON public.%I FOR SELECT TO authenticated USING (true)',tbl);
  END LOOP;
END $$;

-- Personal data must remain tied to the caller on both old and new rows.
DO $$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['caption_saves','profile_dorm_mappings',
    'profile_university_mappings','profile_university_major_mappings']
  LOOP
    EXECUTE format('CREATE POLICY hardened_owner_access ON public.%I FOR ALL TO authenticated
      USING (profile_id = (SELECT auth.uid()))
      WITH CHECK (profile_id = (SELECT auth.uid()))',tbl);
  END LOOP;
END $$;
CREATE POLICY hardened_votes_read ON public.caption_votes FOR SELECT TO authenticated USING (profile_id=(SELECT auth.uid()) OR (SELECT public.is_superadmin(auth.uid())));
CREATE POLICY hardened_votes_insert ON public.caption_votes FOR INSERT TO authenticated
  WITH CHECK (profile_id=(SELECT auth.uid()) AND vote_value IN (-1,1) AND public.can_access_caption(caption_id));
CREATE POLICY hardened_votes_delete ON public.caption_votes FOR DELETE TO authenticated USING (profile_id=(SELECT auth.uid()));
-- Votes are replaced by delete + insert; never allow a vote's caption to be reassigned.
CREATE POLICY hardened_votes_no_update ON public.caption_votes AS RESTRICTIVE FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY hardened_saves_accessible ON public.caption_saves AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.can_access_caption(caption_id));
CREATE POLICY hardened_saves_update_accessible ON public.caption_saves AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (profile_id=(SELECT auth.uid()) OR (SELECT public.is_superadmin(auth.uid())))
  WITH CHECK (public.can_access_caption(caption_id));
CREATE POLICY hardened_requests_read ON public.caption_requests FOR SELECT TO authenticated USING (profile_id=(SELECT auth.uid()));
CREATE POLICY hardened_requests_insert ON public.caption_requests FOR INSERT TO authenticated
  WITH CHECK (profile_id=(SELECT auth.uid()) AND public.can_access_image(image_id));

-- Keep admin/operations data from being writable by every signed-in user.
DO $$
DECLARE p record; tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['ops_run_images','ops_run_steps','ops_runs','experiment_findings','experiments','sidechat_clusterings']
  LOOP
    FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=tbl LOOP
      EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,tbl);
    END LOOP;
    EXECUTE format('CREATE POLICY hardened_admin_access ON public.%I FOR ALL TO authenticated
      USING ((SELECT public.is_superadmin(auth.uid()))) WITH CHECK ((SELECT public.is_superadmin(auth.uid())))',tbl);
  END LOOP;
END $$;
CREATE POLICY hardened_reaction_owner ON public.image_reaction_profiles AS RESTRICTIVE FOR ALL TO authenticated
  USING (profile_id=(SELECT auth.uid()) OR (SELECT public.is_superadmin(auth.uid())))
  WITH CHECK ((profile_id=(SELECT auth.uid()) AND public.can_access_image(image_id)) OR (SELECT public.is_superadmin(auth.uid())));
CREATE POLICY hardened_profiles_update_owner ON public.profiles AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (id=(SELECT auth.uid()) OR (SELECT public.is_superadmin(auth.uid())))
  WITH CHECK (id=(SELECT auth.uid()) OR (SELECT public.is_superadmin(auth.uid())));
CREATE POLICY hardened_profiles_insert_privileges ON public.profiles AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK ((NOT coalesce(is_superadmin,false) AND NOT coalesce(is_matrix_admin,false)
    AND NOT coalesce(is_student_brain_member,false)) OR (SELECT public.is_superadmin(auth.uid())));

-- Existing privilege checks do not protect every privileged field on UPDATE.
CREATE FUNCTION public.guard_profile_privileges() RETURNS trigger LANGUAGE plpgsql
SET search_path = '' AS $$
BEGIN
  IF current_user IN ('anon','authenticated') AND NOT public.is_superadmin(auth.uid())
    AND (NEW.is_superadmin IS DISTINCT FROM OLD.is_superadmin
      OR NEW.is_matrix_admin IS DISTINCT FROM OLD.is_matrix_admin
      OR NEW.is_student_brain_member IS DISTINCT FROM OLD.is_student_brain_member) THEN
    RAISE EXCEPTION 'Only superadmins may change privileged profile fields' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_profile_privileges() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_profile_privileges BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_privileges();

-- A common-use image is a curated resource, even when the uploader owns it.
CREATE POLICY hardened_image_common_use ON public.images AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (true) WITH CHECK (is_common_use IS NOT TRUE OR (SELECT public.is_superadmin(auth.uid())));
CREATE POLICY hardened_captions_insert_visibility ON public.captions AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (coalesce((auth.jwt()->>'is_anonymous')::boolean,false) IS FALSE OR is_public IS FALSE);
CREATE POLICY hardened_captions_update_image ON public.captions AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (true) WITH CHECK (public.can_access_image(image_id));
-- Helpers must check caption visibility as well as image visibility.
CREATE OR REPLACE FUNCTION public.can_access_caption(target_caption_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.captions c
    WHERE c.id=target_caption_id AND public.can_access_image(c.image_id)
      AND (c.is_public IS TRUE OR c.profile_id=auth.uid() OR public.is_superadmin(auth.uid())));
$$;
CREATE OR REPLACE FUNCTION public.can_access_caption(target_caption_id text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.can_access_caption(target_caption_id::uuid);
$$;

-- RLS now prevents voters updating other authors' captions, so this narrow trigger
-- alone maintains the counter. It cannot be called as an RPC.
ALTER FUNCTION public.caption_like_counter_tg() SECURITY DEFINER;
ALTER FUNCTION public.caption_like_counter_tg() SET search_path = '';
REVOKE ALL ON FUNCTION public.caption_like_counter_tg() FROM PUBLIC, anon, authenticated;
-- Clients may edit caption text/visibility; counters and generated scores are server-owned.
REVOKE UPDATE ON public.captions FROM PUBLIC, anon, authenticated;
GRANT UPDATE (content,is_public,modified_by_user_id,modified_datetime_utc) ON public.captions TO authenticated;

ALTER VIEW public.experiment_scorecards SET (security_invoker=true);
ALTER VIEW public.v_caption_controversy SET (security_invoker=true);
ALTER VIEW public.v_caption_trending_week SET (security_invoker=true);
ALTER VIEW public.v_richest_image_dedup SET (security_invoker=true);

-- Pin paths to trusted schemas; pg_temp must be last, and clients cannot create in public.
DO $$
DECLARE f record;
BEGIN
  FOR f IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','funnystudy_notifications') AND p.prokind='f'
      AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig,ARRAY[]::text[])) s WHERE s LIKE 'search_path=%')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid=p.oid AND d.classid='pg_proc'::regclass AND d.deptype='e')
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path=pg_catalog,public,extensions,pg_temp',f.signature);
  END LOOP;
  -- Trigger functions are not client RPCs. Authenticated-only helpers retain policy access.
  FOR f IN SELECT p.oid::regprocedure AS signature,p.prorettype,p.proname
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prosecdef
  LOOP
    IF f.prorettype='trigger'::regtype THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature);
    ELSIF f.proname <> 'receive_telnyx_phone_event' THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',f.signature);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.signature);
    END IF;
  END LOOP;
END $$;

