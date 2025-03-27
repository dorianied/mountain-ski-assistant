/*
  # Remove guest support and enforce user authentication
  
  1. Changes
    - Remove is_guest column from all tables
    - Add user_id column to chat_sessions
    - Update RLS policies to only allow authenticated users
    - Drop existing policies and create new ones
    
  2. Security
    - Enable RLS on all tables
    - Restrict access to authenticated users only
    - Ensure proper data isolation between users
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Allow public access to chat sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Allow public access to chat history" ON chat_history;
DROP POLICY IF EXISTS "session_creation_policy" ON chat_sessions;
DROP POLICY IF EXISTS "session_reading_policy" ON chat_sessions;
DROP POLICY IF EXISTS "session_update_policy" ON chat_sessions;
DROP POLICY IF EXISTS "chat_history_reading_policy" ON chat_history;
DROP POLICY IF EXISTS "chat_history_insertion_policy" ON chat_history;

-- Update chat_sessions table
ALTER TABLE chat_sessions 
DROP COLUMN IF EXISTS is_guest,
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id);

-- Update chat_history table
ALTER TABLE chat_history 
DROP COLUMN IF EXISTS is_guest;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id 
ON chat_sessions(user_id);

-- Enable RLS
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Create policies for chat_sessions
CREATE POLICY "Users can create own sessions"
ON chat_sessions
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own sessions"
ON chat_sessions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions"
ON chat_sessions
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

-- Create policies for chat_history
CREATE POLICY "Users can read own chat history"
ON chat_history
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM chat_sessions
    WHERE chat_sessions.id = chat_history.session_id
    AND chat_sessions.user_id = auth.uid()
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
  )
);