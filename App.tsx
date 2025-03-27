import React, { useState, useEffect } from 'react';
import { Send, Mountain, User, Plus, X, Clock, MessageSquare, LogOut, LogIn, UserPlus } from 'lucide-react';
import { createClient } from '@supabase/supabase-js';
import { LoginModal } from './components/LoginModal';
import { RegisterModal } from './components/RegisterModal';
import { LanguageSelector } from './components/LanguageSelector';
import { translations, Language } from './i18n/translations';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

interface Message {
  content: string;
  type: 'user' | 'assistant';
  suggestedQuestions?: string[];
}

interface ChatHistoryItem {
  id: string;
  message: string;
  response: string;
  created_at: string;
  session_id?: string;
}

interface ChatSession {
  id: string;
  created_at: string;
  last_activity: string;
  is_active: boolean;
  title?: string;
}

function App() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [chatHistory, setChatHistory] = useState<ChatHistoryItem[]>([]);
  const [sessions, setSessions] = useState<ChatSession[]>([]);
  const [currentSession, setCurrentSession] = useState<string | null>(null);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [isProfileMenuOpen, setIsProfileMenuOpen] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [isRegisterModalOpen, setIsRegisterModalOpen] = useState(false);
  const [language, setLanguage] = useState<Language>('en');

  const t = translations[language];

  useEffect(() => {
    checkAuthStatus();
  }, []);

  useEffect(() => {
    if (isAuthenticated) {
      loadSessions();
    } else {
      setSessions([]);
      setCurrentSession(null);
      setChatHistory([]);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    if (currentSession && isAuthenticated) {
      loadChatHistory(currentSession);
    }
  }, [currentSession, isAuthenticated]);

  const checkAuthStatus = async () => {
    try {
      const { data: { session }, error } = await supabase.auth.getSession();
      if (error) throw error;
      setIsAuthenticated(!!session);
    } catch (error) {
      console.error('Error checking auth status:', error);
      setIsAuthenticated(false);
    }
  };

  const handleLogin = async (email: string, password: string) => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) throw error;

      if (data.session) {
        setIsAuthenticated(true);
        setIsLoginModalOpen(false);
        setIsProfileMenuOpen(false);
        loadSessions();
      }
    } catch (error) {
      console.error('Error logging in:', error);
      throw error;
    }
  };

  const handleRegister = async (email: string, password: string, displayName: string) => {
    try {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            display_name: displayName,
          },
        },
      });

      if (error) throw error;

      if (data.user) {
        await handleLogin(email, password);
      }
    } catch (error) {
      console.error('Error registering:', error);
      throw error;
    }
  };

  const loadSessions = async () => {
    if (!isAuthenticated) return;

    try {
      const { data: sessionsData, error: sessionsError } = await supabase
        .from('chat_sessions')
        .select('*')
        .order('last_activity', { ascending: false });

      if (sessionsError) {
        console.error('Error loading sessions:', sessionsError);
        return;
      }

      if (sessionsData && sessionsData.length > 0) {
        setSessions(sessionsData);
        if (!currentSession) {
          setCurrentSession(sessionsData[0].id);
        }
      } else {
        createNewSession();
      }
    } catch (error) {
      console.error('Error:', error);
    }
  };

  const createNewSession = async () => {
    if (!isAuthenticated) {
      setMessages([]);
      return;
    }

    try {
      const { data: userData } = await supabase.auth.getUser();
      if (!userData.user) return;

      const { data, error } = await supabase
        .from('chat_sessions')
        .insert({
          user_id: userData.user.id,
          is_active: true
        })
        .select()
        .single();

      if (error) {
        console.error('Error creating session:', error);
        return;
      }

      if (data) {
        setSessions(prev => [data, ...prev]);
        setCurrentSession(data.id);
        setMessages([]);
      }
    } catch (error) {
      console.error('Error:', error);
    }
  };

  const loadChatHistory = async (sessionId: string) => {
    if (!isAuthenticated) return;

    try {
      const { data, error } = await supabase
        .from('chat_history')
        .select('*')
        .eq('session_id', sessionId)
        .order('created_at', { ascending: true });

      if (error) {
        console.error('Error loading chat history:', error);
        return;
      }

      if (data) {
        setChatHistory(data);
        const historyMessages = data.map((item): Message[] => [
          { type: 'user', content: item.message },
          { 
            type: 'assistant', 
            content: item.response,
            suggestedQuestions: item.suggested_questions
          }
        ]).flat();
        setMessages(historyMessages);
      }
    } catch (error) {
      console.error('Error:', error);
    }
  };

  const handleSendMessage = async () => {
    if (!input.trim()) return;

    const userMessage = input.trim();
    setInput('');
    setMessages(prev => [...prev, { type: 'user', content: userMessage }]);

    try {
      setIsLoading(true);
      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/ski-chat`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message: userMessage }),
      });

      if (!response.ok) {
        throw new Error('Failed to get response');
      }

      const data = await response.json();
      setMessages(prev => [...prev, {
        type: 'assistant',
        content: data.response,
        suggestedQuestions: data.suggestedQuestions,
      }]);

      if (isAuthenticated && currentSession) {
        const { error } = await supabase.from('chat_history').insert({
          message: userMessage,
          response: data.response,
          session_id: currentSession
        });

        if (error) {
          console.error('Error saving to chat history:', error);
        }

        await supabase
          .from('chat_sessions')
          .update({ last_activity: new Date().toISOString() })
          .eq('id', currentSession);

        loadSessions();
      }

    } catch (error) {
      console.error('Error:', error);
      setMessages(prev => [...prev, {
        type: 'assistant',
        content: 'I apologize, but I encountered an error. Please try again.',
      }]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      
      setIsAuthenticated(false);
      setCurrentSession(null);
      setMessages([]);
      setSessions([]);
      setIsProfileMenuOpen(false);
    } catch (error) {
      console.error('Error logging out:', error);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const handleExampleClick = (prompt: string) => {
    setInput(prompt);
  };

  const switchSession = (sessionId: string) => {
    if (sessionId !== currentSession) {
      setCurrentSession(sessionId);
      setMessages([]);
      setInput('');
      setIsHistoryOpen(false);
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric'
    }).format(date);
  };

  const getSessionTitle = (session: ChatSession) => {
    if (session.title) {
      return session.title.length > 50 
        ? session.title.substring(0, 47) + '...'
        : session.title;
    }
    return 'New Chat';
  };

  const handleLogoClick = () => {
    setMessages([]);
    setInput('');
    if (isAuthenticated) {
      createNewSession();
    }
  };

  const examplePrompts = [
    "What's the current avalanche risk in Whistler?",
    "Are the slopes safe for beginners at St. Moritz today?",
    "What safety equipment do I need for off-piste skiing in Chamonix?",
    "How's the visibility at Zermatt's summit today?",
    "Which slopes are groomed at Val d'Isère right now?",
    "What's the snow condition at Courchevel?",
    "Is the Parsenn lift in Davos operating?",
    "Are there any weather warnings in Verbier today?"
  ];

  return (
    <div className="flex flex-col min-h-screen bg-gradient-to-b from-blue-50 to-white">
      <LoginModal
        isOpen={isLoginModalOpen}
        onClose={() => setIsLoginModalOpen(false)}
        onLogin={handleLogin}
        t={translations[language].auth.login}
      />
      
      <RegisterModal
        isOpen={isRegisterModalOpen}
        onClose={() => setIsRegisterModalOpen(false)}
        onRegister={handleRegister}
        t={translations[language].auth.register}
      />
      
      <header className="bg-white shadow-sm">
        <div className="max-w-4xl mx-auto px-4 py-4 flex items-center justify-between">
          <button 
            onClick={handleLogoClick}
            className="flex items-center space-x-2 hover:opacity-80 transition-opacity"
          >
            <Mountain className="h-8 w-8 text-blue-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t.appName}</h1>
          </button>
          <div className="flex items-center space-x-4">
            <LanguageSelector
              currentLanguage={language}
              onLanguageChange={setLanguage}
            />
            <button 
              onClick={() => setIsProfileMenuOpen(!isProfileMenuOpen)}
              className="profile-button p-2 rounded-full hover:bg-gray-100 transition-colors"
            >
              <User className="h-6 w-6 text-gray-600" />
            </button>

            {isProfileMenuOpen && (
              <div className="profile-menu absolute right-0 top-12 w-48 bg-white rounded-lg shadow-lg py-1 z-50">
                {isAuthenticated && (
                  <button
                    onClick={() => {
                      setIsHistoryOpen(true);
                      setIsProfileMenuOpen(false);
                    }}
                    className="w-full px-4 py-2 text-left text-gray-700 hover:bg-gray-100 flex items-center space-x-2"
                  >
                    <MessageSquare className="h-4 w-4" />
                    <span>{t.profile.chatHistory}</span>
                  </button>
                )}
                {isAuthenticated ? (
                  <button
                    onClick={handleLogout}
                    className="w-full px-4 py-2 text-left text-gray-700 hover:bg-gray-100 flex items-center space-x-2"
                  >
                    <LogOut className="h-4 w-4" />
                    <span>{t.profile.logout}</span>
                  </button>
                ) : (
                  <>
                    <button
                      onClick={() => {
                        setIsLoginModalOpen(true);
                        setIsProfileMenuOpen(false);
                      }}
                      className="w-full px-4 py-2 text-left text-gray-700 hover:bg-gray-100 flex items-center space-x-2"
                    >
                      <LogIn className="h-4 w-4" />
                      <span>{t.profile.login}</span>
                    </button>
                    <button
                      onClick={() => {
                        setIsRegisterModalOpen(true);
                        setIsProfileMenuOpen(false);
                      }}
                      className="w-full px-4 py-2 text-left text-gray-700 hover:bg-gray-100 flex items-center space-x-2"
                    >
                      <UserPlus className="h-4 w-4" />
                      <span>{t.profile.register}</span>
                    </button>
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      </header>

      {isHistoryOpen && isAuthenticated && (
        <div className="fixed inset-y-0 right-0 w-80 bg-white shadow-lg transform transition-transform z-40">
          <div className="h-full flex flex-col">
            <div className="p-4 border-b flex items-center justify-between">
              <h2 className="text-lg font-semibold">{t.profile.chatHistory}</h2>
              <button 
                onClick={() => setIsHistoryOpen(false)}
                className="p-1 hover:bg-gray-100 rounded-full"
              >
                <X className="h-5 w-5 text-gray-500" />
              </button>
            </div>
            <div className="p-4 border-b">
              <button
                onClick={createNewSession}
                className="w-full flex items-center justify-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                <Plus className="h-5 w-5" />
                <span>New Chat</span>
              </button>
            </div>
            <div className="flex-1 overflow-y-auto">
              {sessions.map((session) => (
                <button
                  key={session.id}
                  onClick={() => switchSession(session.id)}
                  className={`w-full p-4 text-left border-b hover:bg-gray-50 transition-colors ${
                    currentSession === session.id ? 'bg-blue-50' : ''
                  }`}
                >
                  <div className="flex items-center space-x-3">
                    <MessageSquare className="h-5 w-5 text-gray-500" />
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-gray-900 truncate">
                        {getSessionTitle(session)}
                      </div>
                      <div className="flex items-center text-sm text-gray-500">
                        <Clock className="h-4 w-4 mr-1 flex-shrink-0" />
                        {formatDate(session.last_activity)}
                      </div>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      <div className="flex-1 flex flex-col max-w-4xl mx-auto w-full p-4">
        {messages.length === 0 && (
          <div className="flex-1 flex items-center justify-center">
            <div className="text-center max-w-2xl mx-auto px-4">
              <Mountain className="h-16 w-16 text-blue-600 mx-auto" />
              <h2 className="text-2xl font-semibold text-gray-900 mt-6 mb-4">{t.welcome.title}</h2>
              <p className="text-gray-600 text-lg leading-relaxed mb-6">
                {t.welcome.description}
              </p>
              {!isAuthenticated && (
                <div className="text-sm text-gray-500 space-y-2">
                  <p>{t.welcome.guestMessage}</p>
                  <div className="space-x-2">
                    <button 
                      onClick={() => setIsLoginModalOpen(true)} 
                      className="text-blue-600 hover:underline"
                    >
                      {t.welcome.loginPrompt}
                    </button>
                    <span>{t.welcome.or}</span>
                    <button 
                      onClick={() => setIsRegisterModalOpen(true)} 
                      className="text-blue-600 hover:underline"
                    >
                      {t.welcome.registerPrompt}
                    </button>
                    <span>{t.welcome.saveHistory}</span>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        <div className="flex-1 space-y-4">
          {messages.map((message, index) => (
            <div
              key={index}
              className={`flex ${message.type === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`rounded-lg p-4 max-w-[80%] ${
                  message.type === 'user'
                    ? 'bg-blue-600 text-white'
                    : 'bg-white shadow-md'
                }`}
              >
                <p className="whitespace-pre-wrap">{message.content}</p>
                {message.type === 'assistant' && message.suggestedQuestions && (
                  <div className="mt-4 space-y-2">
                    {message.suggestedQuestions.map((question, qIndex) => (
                      <button
                        key={qIndex}
                        className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-md transition-colors"
                        onClick={() => handleSendMessage()}
                      >
                        {question}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ))}
          {isLoading && (
            <div className="flex justify-start">
              <div className="bg-white shadow-md rounded-lg p-4 max-w-[80%]">
                <div className="flex space-x-2">
                  <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" />
                  <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }} />
                  <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style={{ animationDelay: '0.4s' }} />
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="bg-gray-50 border-t border-b border-gray-200 overflow-hidden mt-4 mb-20">
          <div className="py-2">
            <div className="animate-scrolling-text">
              <div>
                {examplePrompts.map((prompt, index) => (
                  <React.Fragment key={index}>
                    <button
                      onClick={() => handleExampleClick(prompt)}
                      className="inline-block px-2 text-gray-600 hover:text-blue-600 cursor-pointer transition-colors"
                    >
                      {prompt}
                    </button>
                    <span className="text-gray-400 px-2">•</span>
                  </React.Fragment>
                ))}
              </div>
              <div>
                {examplePrompts.map((prompt, index) => (
                  <React.Fragment key={`duplicate-${index}`}>
                    <button
                      onClick={() => handleExampleClick(prompt)}
                      className="inline-block px-2 text-gray-600 hover:text-blue-600 cursor-pointer transition-colors"
                    >
                      {prompt}
                    </button>
                    <span className="text-gray-400 px-2">•</span>
                  </React.Fragment>
                ))}
              </div>
            </div>
          </div>
        </div>

        <div className="fixed bottom-0 left-0 right-0 p-4 bg-white border-t border-gray-200">
          <div className="max-w-4xl mx-auto flex gap-4">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder={t.chat.inputPlaceholder}
              className="flex-1 rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white"
            />
            <button
              onClick={handleSendMessage}
              disabled={isLoading || !input.trim()}
              className="bg-blue-600 text-white rounded-lg px-4 py-2 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Send className="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;