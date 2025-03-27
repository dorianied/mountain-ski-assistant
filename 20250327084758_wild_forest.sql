/*
  # Fix chat sessions RLS policies

  1. Changes
    - Drop and recreate RLS policies for chat_sessions table
    - Fix guest access issues
    - Ensure proper session management for both guests and authenticated users

  2. Security
    - Maintain security while allowing proper access
    - Fix policy issues preventing session creation
    - Ensure proper access control for both guests and authenticated users
*/

-- First, drop all existing policies
DO $$ 
BEGIN
  -- Drop chat_sessions policies
  DROP POLICY IF EXISTS "Allow session creation" ON chat_sessions;
  DROP POLICY IF EXISTS "Allow session reading" ON chat_sessions;
  DROP POLICY IF EXISTS "Allow session updates" ON chat_sessions;
  DROP POLICY IF EXISTS "Users can create own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Users can read own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Users can update own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can create sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can read recent sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can update own sessions" ON chat_sessions;

  -- Drop chat_history policies
  DROP POLICY IF EXISTS "Allow chat history reading" ON chat_history;
  DROP POLICY IF EXISTS "Allow chat message insertion" ON chat_history;
  DROP POLICY IF EXISTS "Users can read own chat history" ON chat_history;
  DROP POLICY IF EXISTS "Users can insert own chat messages" ON chat_history;
  DROP POLICY IF EXISTS "Guests can read recent chat history" ON chat_history;
  DROP POLICY IF EXISTS "Guests can insert chat messages" ON chat_history;
END $$;

-- Create new policies with unique names
CREATE POLICY "session_creation_policy"
ON chat_sessions
FOR INSERT
TO public
WITH CHECK (
  (auth.uid() IS NULL AND is_guest = true) OR
  (auth.uid() = user_id AND NOT is_guest)
);

CREATE POLICY "session_reading_policy"
ON chat_sessions
FOR SELECT
TO public
USING (
  (auth.uid() IS NULL AND is_guest = true AND created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')) OR
  (auth.uid() = user_id AND NOT is_guest)
);

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