import React from 'react';
import { Languages } from 'lucide-react';
import { Language } from '../i18n/translations';

interface LanguageSelectorProps {
  currentLanguage: Language;
  onLanguageChange: (language: Language) => void;
}

export function LanguageSelector({ currentLanguage, onLanguageChange }: LanguageSelectorProps) {
  return (
    <div className="relative">
      <button
        className="p-2 rounded-full hover:bg-gray-100 transition-colors flex items-center space-x-1"
        onClick={() => onLanguageChange(currentLanguage === 'en' ? 'fr' : 'en')}
      >
        <Languages className="h-5 w-5 text-gray-600" />
        <span className="text-sm font-medium text-gray-600 uppercase">{currentLanguage}</span>
      </button>
    </div>
  );
}