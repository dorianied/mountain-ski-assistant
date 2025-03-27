/*
  # Add chat sessions support

  1. New Tables
    - `chat_sessions`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `is_guest` (boolean)
      - `created_at` (timestamp)
      - `last_activity` (timestamp)
      - `is_active` (boolean)

  2. Changes to chat_history
    - Add `session_id` column to link messages to sessions
    - Add index for efficient session querying

  3. Security
    - Enable RLS on chat_sessions table
    - Add policies for both authenticated and guest users
*/

-- Create chat_sessions table
CREATE TABLE IF NOT EXISTS chat_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  is_guest boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  last_activity timestamptz DEFAULT now(),
  is_active boolean DEFAULT true
);

-- Add session_id to chat_history
ALTER TABLE chat_history 
ADD COLUMN IF NOT EXISTS session_id uuid REFERENCES chat_sessions(id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_active 
ON chat_sessions(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_guest_active 
ON chat_sessions(is_guest, is_active);

CREATE INDEX IF NOT EXISTS idx_chat_history_session 
ON chat_history(session_id);

-- Enable RLS on chat_sessions
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

-- Policies for chat_sessions
CREATE POLICY "Users can create own sessions"
ON chat_sessions
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id AND 
  NOT is_guest
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

-- Update chat_history policies to include session_id
DROP POLICY IF EXISTS "Users can read own chat history" ON chat_history;
DROP POLICY IF EXISTS "Users can insert own chat messages" ON chat_history;
DROP POLICY IF EXISTS "Guests can read recent chat history" ON chat_history;
DROP POLICY IF EXISTS "Guests can insert chat messages" ON chat_history;

CREATE POLICY "Users can read own chat history"
ON chat_history
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM chat_sessions
    WHERE chat_sessions.id = chat_history.session_id
    AND chat_sessions.user_id = auth.uid()
    AND NOT chat_sessions.is_guest
  )
);

CREATE POLICY "Users can insert own chat messages"
ON chat_history
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM chat_sessions
    WHERE chat_sessions.id = chat_history.session_id
    AND chat_sessions.user_id = auth.uid()
    AND NOT chat_sessions.is_guest
  )
);

CREATE POLICY "Guests can read recent chat history"
ON chat_history
FOR SELECT
TO anon
USING (
  EXISTS (
    SELECT 1 FROM chat_sessions
    WHERE chat_sessions.id = chat_history.session_id
    AND chat_sessions.is_guest = true
    AND chat_sessions.created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
  )
);

CREATE POLICY "Guests can insert chat messages"
ON chat_history
FOR INSERT
TO anon
WITH CHECK (
  EXISTS (
    SELECT 1 FROM chat_sessions
    WHERE chat_sessions.id = chat_history.session_id
    AND chat_sessions.is_guest = true
    AND chat_sessions.created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
  )
);