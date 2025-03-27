/*
  # Fix chat history table schema

  1. Changes
    - Add `is_guest` column to `chat_history` table if it doesn't exist
    - Ensure RLS policies are properly set up
    - Add performance index

  2. Security
    - Enable RLS
    - Set up policies for both authenticated and guest users
    - Ensure proper access control based on user status
*/

-- First check if the column exists and create it if it doesn't
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'chat_history' 
    AND column_name = 'is_guest'
  ) THEN
    ALTER TABLE chat_history ADD COLUMN is_guest boolean DEFAULT false;
  END IF;
END $$;

-- Create index if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_chat_history_user_guest 
ON chat_history(user_id, is_guest);

-- Enable RLS
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Safely drop existing policies
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can insert own chat messages" ON chat_history;
    DROP POLICY IF EXISTS "Users can read own chat history" ON chat_history;
    DROP POLICY IF EXISTS "Guests can insert chat messages" ON chat_history;
    DROP POLICY IF EXISTS "Guests can read recent chat history" ON chat_history;
END $$;

-- Recreate policies
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