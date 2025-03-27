/*
  # Fix chat session title trigger

  1. Changes
    - Drop and recreate the trigger function with proper error handling
    - Add logging for debugging
    - Ensure proper session title updates

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
DECLARE
  message_count INTEGER;
BEGIN
  -- Get count of existing messages for this session
  SELECT COUNT(*)
  INTO message_count
  FROM chat_history
  WHERE session_id = NEW.session_id;

  -- Only update title if this is the first message (count = 1 because NEW row is already inserted)
  IF message_count = 1 THEN
    UPDATE chat_sessions 
    SET title = NEW.message 
    WHERE id = NEW.session_id;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log any errors but don't fail the transaction
  RAISE NOTICE 'Error in update_session_title: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
CREATE TRIGGER update_session_title_trigger
AFTER INSERT ON chat_history
FOR EACH ROW
EXECUTE FUNCTION update_session_title();