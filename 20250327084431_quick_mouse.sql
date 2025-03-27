/*
  # Add chat sessions support

  1. Changes
    - Create chat_sessions table if it doesn't exist
    - Add session_id to chat_history if it doesn't exist
    - Create necessary indexes
    - Set up RLS policies for both tables
    - Handle existing policies safely

  2. Security
    - Enable RLS on chat_sessions
    - Add policies for both authenticated and guest users
    - Update chat_history policies to work with sessions
*/

-- First, safely create the chat_sessions table
CREATE TABLE IF NOT EXISTS chat_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  is_guest boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  last_activity timestamptz DEFAULT now(),
  is_active boolean DEFAULT true
);

-- Add session_id to chat_history if it doesn't exist
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'chat_history' 
    AND column_name = 'session_id'
  ) THEN
    ALTER TABLE chat_history 
    ADD COLUMN session_id uuid REFERENCES chat_sessions(id);
  END IF;
END $$;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_active 
ON chat_sessions(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_guest_active 
ON chat_sessions(is_guest, is_active);

CREATE INDEX IF NOT EXISTS idx_chat_history_session 
ON chat_history(session_id);

-- Enable RLS on chat_sessions
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

-- Safely drop existing policies on chat_sessions
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can create own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Users can read own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Users can update own sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can create sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can read recent sessions" ON chat_sessions;
  DROP POLICY IF EXISTS "Guests can update own sessions" ON chat_sessions;
END $$;

-- Create policies for chat_sessions
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_sessions' 
    AND policyname = 'Users can create own sessions'
  ) THEN
    CREATE POLICY "Users can create own sessions"
    ON chat_sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (
      auth.uid() = user_id AND 
      NOT is_guest
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_sessions' 
    AND policyname = 'Users can read own sessions'
  ) THEN
    CREATE POLICY "Users can read own sessions"
    ON chat_sessions
    FOR SELECT
    TO authenticated
    USING (
      auth.uid() = user_id AND 
      NOT is_guest
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_sessions' 
    AND policyname = 'Users can update own sessions'
  ) THEN
    CREATE POLICY "Users can update own sessions"
    ON chat_sessions
    FOR UPDATE
    TO authenticated
    USING (
      auth.uid() = user_id AND 
      NOT is_guest
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_sessions' 
    AND policyname = 'Guests can create sessions'
  ) THEN
    CREATE POLICY "Guests can create sessions"
    ON chat_sessions
    FOR INSERT
    TO anon
    WITH CHECK (
      user_id IS NULL AND 
      is_guest = true
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_sessions' 
    AND policyname = 'Guests can read recent sessions'
  ) THEN
    CREATE POLICY "Guests can read recent sessions"
    ON chat_sessions
    FOR SELECT
    TO anon
    USING (
      is_guest = true AND 
      created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_sessions' 
    AND policyname = 'Guests can update own sessions'
  ) THEN
    CREATE POLICY "Guests can update own sessions"
    ON chat_sessions
    FOR UPDATE
    TO anon
    USING (
      is_guest = true AND 
      created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
    );
  END IF;
END $$;

-- Update chat_history policies to include session_id
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can read own chat history" ON chat_history;
  DROP POLICY IF EXISTS "Users can insert own chat messages" ON chat_history;
  DROP POLICY IF EXISTS "Guests can read recent chat history" ON chat_history;
  DROP POLICY IF EXISTS "Guests can insert chat messages" ON chat_history;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_history' 
    AND policyname = 'Users can read own chat history'
  ) THEN
    CREATE POLICY "Users can read own chat history"
    ON chat_history
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM chat_sessions
        WHERE chat_sessions.id = chat_history.session_id
        AND chat_sessions.user_id = auth.uid()
        AND NOT chat_sessions.is_guest
      )
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_history' 
    AND policyname = 'Users can insert own chat messages'
  ) THEN
    CREATE POLICY "Users can insert own chat messages"
    ON chat_history
    FOR INSERT
    TO authenticated
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM chat_sessions
        WHERE chat_sessions.id = chat_history.session_id
        AND chat_sessions.user_id = auth.uid()
        AND NOT chat_sessions.is_guest
      )
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_history' 
    AND policyname = 'Guests can read recent chat history'
  ) THEN
    CREATE POLICY "Guests can read recent chat history"
    ON chat_history
    FOR SELECT
    TO anon
    USING (
      EXISTS (
        SELECT 1 FROM chat_sessions
        WHERE chat_sessions.id = chat_history.session_id
        AND chat_sessions.is_guest = true
        AND chat_sessions.created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
      )
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'chat_history' 
    AND policyname = 'Guests can insert chat messages'
  ) THEN
    CREATE POLICY "Guests can insert chat messages"
    ON chat_history
    FOR INSERT
    TO anon
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM chat_sessions
        WHERE chat_sessions.id = chat_history.session_id
        AND chat_sessions.is_guest = true
        AND chat_sessions.created_at > (CURRENT_TIMESTAMP - INTERVAL '24 hours')
      )
    );
  END IF;
END $$;