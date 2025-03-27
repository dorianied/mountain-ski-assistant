/*
  # Fix chat session title trigger

  1. Changes
    - Drop and recreate trigger function with proper message counting
    - Add better error handling and logging
    - Ensure session title updates correctly
    - Add index for better performance

  2. Security
    - No changes to security policies needed
    - Maintains existing access controls
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS update_session_title_trigger ON chat_history;
DROP FUNCTION IF EXISTS update_session_title();

-- Create improved function to update session title
CREATE OR REPLACE FUNCTION update_session_title()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the session title immediately for the first message
  UPDATE chat_sessions 
  SET title = NEW.message 
  WHERE id = NEW.session_id 
  AND NOT EXISTS (
    SELECT 1 
    FROM chat_history 
    WHERE session_id = NEW.session_id 
    AND id != NEW.id
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log any errors but don't fail the transaction
  RAISE NOTICE 'Error in update_session_title: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_session_title_trigger
AFTER INSERT ON chat_history
FOR EACH ROW
EXECUTE FUNCTION update_session_title();

-- Create index to optimize the EXISTS query
CREATE INDEX IF NOT EXISTS idx_chat_history_session_message 
ON chat_history(session_id, id);

-- Update existing sessions with their first message as title
UPDATE chat_sessions cs
SET title = ch.message
FROM (
  SELECT DISTINCT ON (session_id) 
    session_id,
    message,
    created_at
  FROM chat_history
  ORDER BY session_id, created_at ASC
) ch
WHERE cs.id = ch.session_id
AND cs.title IS NULL;