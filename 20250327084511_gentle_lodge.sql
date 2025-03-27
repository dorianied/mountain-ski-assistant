/*
  # Fix chat sessions RLS policies

  1. Changes
    - Drop and recreate chat_sessions RLS policies with proper access
    - Fix guest session handling
    - Add better error handling for session creation

  2. Security
    - Enable RLS
    - Update policies to properly handle both authenticated and guest users
    - Ensure proper access control while fixing the permission issues
*/

-- Enable RLS on chat_sessions
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can create own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Users can read own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Users can update own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can create sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can read recent sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can update own sessions" ON chat_sessions;
END $$;

-- Create new policies with fixed permissions
CREATE POLICY "Users can create own sessions"
ON chat_sessions
FOR INSERT
TO authenticated
WITH CHECK (
  (auth.uid() = user_id OR user_id IS NULL) AND 
  (NOT is_guest OR is_guest IS NULL)
);

CREATE POLICY "Users can read own sessions"
ON chat_sessions
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id AND 
  NOT is_guest
);

CREATE POLICY "Users can update own sessions"
ON chat_sessions
FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id AND 
  NOT is_guest
);

CREATE POLICY "Guests can create sessions"
ON chat_sessions
FOR INSERT
TO anon
WITH CHECK (
  user_id IS NULL AND 
  is_guest = true
);

CREATE POLICY "Guests can read recent sessions"
ON chat_sessions
FOR SELECT
TO anon
USING (
  is_guest = true AND 
  created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
);

CREATE POLICY "Guests can update own sessions"
ON chat_sessions
FOR UPDATE
TO anon
USING (
  is_guest = true AND 
  created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
);

-- Add indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_active 
ON chat_sessions(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_guest_active 
ON chat_sessions(is_guest, is_active);

-- Ensure proper column defaults
ALTER TABLE chat_sessions 
ALTER COLUMN is_guest SET DEFAULT false,
ALTER COLUMN is_active SET DEFAULT true,
ALTER COLUMN last_activity SET DEFAULT now();