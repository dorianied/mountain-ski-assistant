/*
  # Add is_guest column to chat_history table

  1. Changes
    - Add is_guest column to chat_history table
    - Set default value to false
    - Update RLS policies to handle guest access
*/

-- Add is_guest column if it doesn't exist
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

-- Ensure RLS is enabled
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Update policies to handle guest access
DROP POLICY IF EXISTS "Allow public access to chat history" ON chat_history;

CREATE POLICY "Allow public access to chat history"
ON chat_history
FOR ALL
TO public
USING (true)
WITH CHECK (true);