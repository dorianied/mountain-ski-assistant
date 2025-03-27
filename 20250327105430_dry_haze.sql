/*
  # Add title to chat sessions

  1. Changes
    - Add title column to chat_sessions table
    - Add function to extract first message as title
    - Add trigger to update session title on first message

  2. Security
    - Maintain existing RLS policies
    - No changes to access control needed
*/

-- Add title column to chat_sessions
ALTER TABLE chat_sessions 
ADD COLUMN IF NOT EXISTS title text;

-- Create function to update session title
CREATE OR REPLACE FUNCTION update_session_title()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update title if it's the first message in the session
  IF NOT EXISTS (
    SELECT 1 FROM chat_history 
    WHERE session_id = NEW.session_id 
    AND id != NEW.id
  ) THEN
    UPDATE chat_sessions 
    SET title = NEW.message 
    WHERE id = NEW.session_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update session title
DROP TRIGGER IF EXISTS update_session_title_trigger ON chat_history;
CREATE TRIGGER update_session_title_trigger
AFTER INSERT ON chat_history
FOR EACH ROW
EXECUTE FUNCTION update_session_title();