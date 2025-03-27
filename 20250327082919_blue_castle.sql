/*
  # Fix chat history table and policies

  1. Changes
    - Add indexes for better query performance
    - Update RLS policies for better access control
    - Ensure proper column constraints

  2. Security
    - Enable RLS
    - Set up policies for both authenticated and guest users
    - Ensure proper access control based on user status
*/

-- First ensure the table exists with proper structure
CREATE TABLE IF NOT EXISTS chat_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  message text NOT NULL,
  response text NOT NULL,
  created_at timestamptz DEFAULT now(),
  is_guest boolean DEFAULT false
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_history_user_id ON chat_history(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_history_created_at ON chat_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_history_guest_created ON chat_history(is_guest, created_at DESC);

-- Enable RLS
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can insert own chat messages" ON chat_history;
    DROP POLICY IF EXISTS "Users can read own chat history" ON chat_history;
    DROP POLICY IF EXISTS "Guests can insert chat messages" ON chat_history;
    DROP POLICY IF EXISTS "Guests can read recent chat history" ON chat_history;
END $$;

-- Create new policies with proper access control
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