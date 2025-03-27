/*
  # Add user registration support

  1. Changes
    - Add display_name field to auth.users table
    - Add index for efficient user searches
    - Note: Email confirmation is handled by Supabase auth settings

  2. Security
    - Maintain existing security settings
    - No changes to RLS policies needed
*/

-- Add display_name column to auth.users if it doesn't exist
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'auth' 
    AND table_name = 'users' 
    AND column_name = 'display_name'
  ) THEN
    ALTER TABLE auth.users
    ADD COLUMN display_name text;
  END IF;
END $$;

-- Add registration-specific indexes if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'auth'
    AND tablename = 'users'
    AND indexname = 'idx_users_display_name'
  ) THEN
    CREATE INDEX idx_users_display_name ON auth.users(display_name);
  END IF;
END $$;