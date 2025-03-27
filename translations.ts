export type Language = 'en' | 'fr';

export const translations = {
  en: {
    appName: 'MountAIn',
    welcome: {
      title: 'Welcome to MountAIn',
      description: 'Your intelligent ski safety assistant. Ask me anything about current conditions, safety recommendations, and real-time updates from ski resorts worldwide.',
      guestMessage: "You're chatting as a guest. Your messages won't be saved.",
      loginPrompt: 'Log in',
      registerPrompt: 'create an account',
      saveHistory: 'to save your chat history.',
      or: 'or'
    },
    chat: {
      inputPlaceholder: 'Ask about ski conditions, safety, or resort information...',
      loading: 'Loading...'
    },
    auth: {
      login: {
        title: 'Login',
        email: 'Email',
        password: 'Password',
        submit: 'Login',
        submitting: 'Logging in...'
      },
      register: {
        title: 'Create Account',
        displayName: 'Display Name',
        email: 'Email',
        password: 'Password',
        submit: 'Create Account',
        submitting: 'Creating account...',
        error: 'Registration failed. Please try again.'
      }
    },
    profile: {
      chatHistory: 'Chat History',
      logout: 'Logout',
      login: 'Login',
      register: 'Register'
    }
  },
  fr: {
    appName: 'MountAIn',
    welcome: {
      title: 'Bienvenue sur MountAIn',
      description: 'Votre assistant intelligent pour la sécurité en ski. Posez-moi des questions sur les conditions actuelles, les recommandations de sécurité et les mises à jour en temps réel des stations de ski du monde entier.',
      guestMessage: 'Vous discutez en tant qu\'invité. Vos messages ne seront pas sauvegardés.',
      loginPrompt: 'Connectez-vous',
      registerPrompt: 'créez un compte',
      saveHistory: 'pour sauvegarder votre historique de discussion.',
      or: 'ou'
    },
    chat: {
      inputPlaceholder: 'Posez des questions sur les conditions de ski, la sécurité ou les informations sur les stations...',
      loading: 'Chargement...'
    },
    auth: {
      login: {
        title: 'Connexion',
        email: 'Email',
        password: 'Mot de passe',
        submit: 'Se connecter',
        submitting: 'Connexion en cours...'
      },
      register: {
        title: 'Créer un compte',
        displayName: 'Nom d\'affichage',
        email: 'Email',
        password: 'Mot de passe',
        submit: 'Créer un compte',
        submitting: 'Création du compte...',
        error: 'L\'inscription a échoué. Veuillez réessayer.'
      }
    },
    profile: {
      chatHistory: 'Historique des discussions',
      logout: 'Déconnexion',
      login: 'Connexion',
      register: 'S\'inscrire'
    }
  }
};