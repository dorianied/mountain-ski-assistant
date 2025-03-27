/*
  # Add chat sessions support

  1. Changes
    - Create chat_sessions table
    - Update chat_history to reference sessions
    - Add necessary indexes and constraints
    - Update RLS policies

  2. Security
    - Enable RLS on all tables
    - Set up policies for both guest and authenticated access
*/

-- Create chat_sessions table
CREATE TABLE IF NOT EXISTS chat_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz DEFAULT now(),
  last_activity timestamptz DEFAULT now(),
  is_active boolean DEFAULT true,
  is_guest boolean DEFAULT false
);

-- Update chat_history table
ALTER TABLE chat_history 
ADD COLUMN IF NOT EXISTS session_id uuid REFERENCES chat_sessions(id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_chat_sessions_activity 
ON chat_sessions(last_activity DESC);

CREATE INDEX IF NOT EXISTS idx_chat_history_session 
ON chat_history(session_id);

-- Enable RLS
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Create policies for chat_sessions
CREATE POLICY "Allow public access to chat sessions"
ON chat_sessions
FOR ALL
TO public
USING (true)
WITH CHECK (true);

-- Update chat_history policies
DROP POLICY IF EXISTS "Allow public access to chat history" ON chat_history;

CREATE POLICY "Allow public access to chat history"
ON chat_history
FOR ALL
TO public
USING (true)
WITH CHECK (true);