/*
  # Rollback to version without authentication
  
  1. Changes
    - Drop all tables and start fresh
    - Create simple chat_history table without auth
    - Remove all auth-related features
    - Set up public access policies
    
  2. Security
    - Enable RLS
    - Allow public access for chat functionality
*/

-- Drop existing tables
DROP TABLE IF EXISTS chat_history CASCADE;
DROP TABLE IF EXISTS chat_sessions CASCADE;

-- Remove auth-related columns
ALTER TABLE auth.users DROP COLUMN IF EXISTS display_name;

-- Create simplified chat_history table
CREATE TABLE IF NOT EXISTS chat_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message text NOT NULL,
  response text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create index for timestamp-based queries
CREATE INDEX IF NOT EXISTS idx_chat_history_created_at 
ON chat_history(created_at DESC);

-- Enable RLS
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- Create public access policy
CREATE POLICY "Allow public access to chat history"
ON chat_history
FOR ALL
TO public
USING (true)
WITH CHECK (true);