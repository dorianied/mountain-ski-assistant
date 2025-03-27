/*
  # Add guest support while maintaining user accounts

  1. Changes
    - Add session management for both guests and authenticated users
    - Ensure chat history can be accessed by both types of users
    - Allow seamless transition from guest to authenticated user

  2. Security
    - Enable RLS on all tables
    - Set up policies for both guest and authenticated access
    - Ensure proper data isolation between users
*/

-- Create chat_sessions table if it doesn't exist
CREATE TABLE IF NOT EXISTS chat_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  is_guest boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  last_activity timestamptz DEFAULT now(),
  is_active boolean DEFAULT true
);

-- Create chat_history table if it doesn't exist
CREATE TABLE IF NOT EXISTS chat_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES chat_sessions(id),
  message text NOT NULL,
  response text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_active 
ON chat_sessions(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_guest_active 
ON chat_sessions(is_guest, is_active);

CREATE INDEX IF NOT EXISTS idx_chat_history_session 
ON chat_history(session_id);

-- Enable RLS
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "session_creation_policy" ON chat_sessions;
    DROP POLICY IF EXISTS "session_reading_policy" ON chat_sessions;
    DROP POLICY IF EXISTS "session_update_policy" ON chat_sessions;
    DROP POLICY IF EXISTS "chat_history_reading_policy" ON chat_history;
    DROP POLICY IF EXISTS "chat_history_insertion_policy" ON chat_history;
END $$;

-- Policies for chat_sessions
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
  (auth.uid() IS NULL AND is_guest = true AND created_at > (CURRENT_TIMESTAMP - '24:00:00'::interval)) OR
  (auth.uid() = user_id AND NOT is_guest)
);

CREATE POLICY "session_update_policy"
ON chat_sessions
FOR UPDATE
TO public
USING (
  (auth.uid() IS NULL AND is_guest = true AND created_at > (CURRENT_TIMESTAMP - '24:00:00'::interval)) OR
  (auth.uid() = user_id AND NOT is_guest)
);

-- Policies for chat_history
CREATE POLICY "chat_history_reading_policy"
ON chat_history
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1 FROM chat_sessions
    WHERE chat_sessions.id = chat_history.session_id
    AND (
      (auth.uid() IS NULL AND chat_sessions.is_guest = true AND chat_sessions.created_at > (CURRENT_TIMESTAMP - '24:00:00'::interval)) OR
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
      (auth.uid() IS NULL AND chat_sessions.is_guest = true AND chat_sessions.created_at > (CURRENT_TIMESTAMP - '24:00:00'::interval)) OR
      (auth.uid() = chat_sessions.user_id AND NOT chat_sessions.is_guest)
    )
  )
);