/*
  # Rollback to production version

  1. Changes
    - Drop recent tables and policies
    - Restore original chat_history table structure
    - Restore original RLS policies

  2. Security
    - Maintain RLS security
    - Restore original access controls
*/

-- Drop new tables and columns
DROP TABLE IF EXISTS chat_history CASCADE;
DROP TABLE IF EXISTS chat_sessions CASCADE;

-- Remove display_name from auth.users
ALTER TABLE auth.users DROP COLUMN IF EXISTS display_name;

-- Recreate chat_history table with original structure
CREATE TABLE IF NOT EXISTS chat_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  message text NOT NULL,
  response text NOT NULL,
  created_at timestamptz DEFAULT now(),
  is_guest boolean DEFAULT false
);

-- Create original indexes
CREATE INDEX IF NOT EXISTS idx_chat_history_user_id ON chat_history(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_history_created_at ON chat_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_history_guest_created ON chat_history(is_guest, created_at DESC);

-- Enable RLS
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Create original policies
CREATE POLICY "Users can insert own chat messages"
ON chat_history
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id AND 
  NOT is_guest
);

CREATE POLICY "Users can read own chat history"
ON chat_history
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id AND 
  NOT is_guest
);

CREATE POLICY "Guests can insert chat messages"
ON chat_history
FOR INSERT
TO anon
WITH CHECK (
  user_id IS NULL AND 
  is_guest = true
);

CREATE POLICY "Guests can read recent chat history"
ON chat_history
FOR SELECT
TO anon
USING (
  is_guest = true AND 
  created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
);