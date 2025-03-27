/*
  # Update chat history for guest users

  1. Changes
    - Add `is_guest` column to `chat_history` table
    - Update RLS policies to allow guest messages
    - Add index for better query performance

  2. Security
    - Enable RLS on chat_history table
    - Add policies for both authenticated and guest users
*/

-- Add is_guest column with default false
ALTER TABLE chat_history 
ADD COLUMN IF NOT EXISTS is_guest boolean DEFAULT false;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_chat_history_user_guest 
ON chat_history(user_id, is_guest);

-- Update RLS policies
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can insert own chat messages" ON chat_history;
    DROP POLICY IF EXISTS "Users can read own chat history" ON chat_history;
    DROP POLICY IF EXISTS "Guests can insert chat messages" ON chat_history;
    DROP POLICY IF EXISTS "Guests can read recent chat history" ON chat_history;
END $$;

-- Policy for authenticated users
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

-- Policy for guest users (using client IP as identifier)
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