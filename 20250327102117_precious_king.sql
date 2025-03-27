/*
  # Update chat session and history policies

  1. Changes
    - Safely recreate policies for chat_sessions and chat_history
    - Add checks to prevent duplicate policy creation
    - Ensure proper access control for both guests and authenticated users

  2. Security
    - Maintain RLS security
    - Update policies with proper access controls
    - Handle both guest and authenticated user scenarios
*/

-- Drop existing policies safely
DO $$ 
BEGIN
  -- Drop chat_sessions policies if they exist
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'session_creation_policy') THEN
    DROP POLICY "session_creation_policy" ON chat_sessions;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'session_reading_policy') THEN
    DROP POLICY "session_reading_policy" ON chat_sessions;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'session_update_policy') THEN
    DROP POLICY "session_update_policy" ON chat_sessions;
  END IF;

  -- Drop chat_history policies if they exist
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_history_reading_policy') THEN
    DROP POLICY "chat_history_reading_policy" ON chat_history;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_history_insertion_policy') THEN
    DROP POLICY "chat_history_insertion_policy" ON chat_history;
  END IF;
END $$;

-- Create policies for chat_sessions
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'session_creation_policy') THEN
    CREATE POLICY "session_creation_policy"
    ON chat_sessions
    FOR INSERT
    TO public
    WITH CHECK (
      (auth.uid() IS NULL AND is_guest = true) OR
      (auth.uid() = user_id AND NOT is_guest)
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'session_reading_policy') THEN
    CREATE POLICY "session_reading_policy"
    ON chat_sessions
    FOR SELECT
    TO public
    USING (
      (auth.uid() IS NULL AND is_guest = true AND created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')) OR
      (auth.uid() = user_id AND NOT is_guest)
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'session_update_policy') THEN
    CREATE POLICY "session_update_policy"
    ON chat_sessions
    FOR UPDATE
    TO public
    USING (
      (auth.uid() IS NULL AND is_guest = true AND created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')) OR
      (auth.uid() = user_id AND NOT is_guest)
    )
    WITH CHECK (
      (auth.uid() IS NULL AND is_guest = true AND created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')) OR
      (auth.uid() = user_id AND NOT is_guest)
    );
  END IF;
END $$;

-- Create policies for chat_history
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_history_reading_policy') THEN
    CREATE POLICY "chat_history_reading_policy"
    ON chat_history
    FOR SELECT
    TO public
    USING (
      EXISTS (
        SELECT 1 FROM chat_sessions
        WHERE chat_sessions.id = chat_history.session_id
        AND (
          (auth.uid() IS NULL AND chat_sessions.is_guest = true AND chat_sessions.created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours'))
          OR
          (auth.uid() = chat_sessions.user_id AND NOT chat_sessions.is_guest)
        )
      )
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'chat_history_insertion_policy') THEN
    CREATE POLICY "chat_history_insertion_policy"
    ON chat_history
    FOR INSERT
    TO public
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM chat_sessions
        WHERE chat_sessions.id = chat_history.session_id
        AND (
          (auth.uid() IS NULL AND chat_sessions.is_guest = true AND chat_sessions.created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours'))
          OR
          (auth.uid() = chat_sessions.user_id AND NOT chat_sessions.is_guest)
        )
      )
    );
  END IF;
END $$;