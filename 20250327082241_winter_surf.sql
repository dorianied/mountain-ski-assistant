/*
  # Update chat history table and policies

  1. Changes
    - Safely create chat_history table if it doesn't exist
    - Update indexes for better performance
    - Ensure RLS is enabled
    - Safely recreate policies

  2. Security
    - Enable RLS
    - Set up policies for both authenticated and guest users
    - Ensure proper access control based on user status
*/

-- First check if the table exists and create it if it doesn't
CREATE TABLE IF NOT EXISTS chat_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  message text NOT NULL,
  response text NOT NULL,
  created_at timestamptz DEFAULT now(),
  is_guest boolean DEFAULT false
);

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