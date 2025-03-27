import { OpenAI } from 'npm:openai@4.28.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Max-Age': '86400',
  'Content-Type': 'application/json'
};

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');

const openai = new OpenAI({
  apiKey: OPENAI_API_KEY,
});

function formatResponse(content: string): string {
  const sections = content.split('\n\n');
  
  const formattedSections = sections.map(section => {
    if (section.toLowerCase().includes('quick summary')) {
      return section.replace('Quick Summary:', '🚨 Quick Summary:');
    }
    if (section.toLowerCase().includes('key conditions')) {
      return section.replace('Key Conditions:', '🔍 Key Conditions:');
    }
    if (section.toLowerCase().includes('safety status')) {
      return section.replace('Safety Status:', '⚠️ Safety Status:');
    }
    if (section.toLowerCase().includes('trail conditions')) {
      return section.replace('Trail Conditions:', '🎿 Trail Conditions:');
    }
    if (section.toLowerCase().includes('recommendations')) {
      return section.replace('Recommendations:', '✅ Recommendations:');
    }
    return section;
  });

  const bulletedContent = formattedSections.map(section => {
    return section.split('\n').map(line => {
      if (line.startsWith('•')) {
        return line;
      }
      if (line.includes(':')) {
        return line;
      }
      if (line.trim() === '') {
        return line;
      }
      return '• ' + line;
    }).join('\n');
  });

  return bulletedContent.join('\n\n');
}

async function validateApiKey(): Promise<boolean> {
  try {
    if (!OPENAI_API_KEY) {
      console.error('OpenAI API key is missing');
      return false;
    }

    const response = await openai.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: 'test' }],
      max_tokens: 1
    });

    return true;
  } catch (error) {
    console.error('API key validation error:', error);
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { 
          status: 405,
          headers: corsHeaders 
        }
      );
    }

    let requestData;
    try {
      requestData = await req.json();
    } catch (e) {
      return new Response(
        JSON.stringify({
          error: 'Invalid request format',
        }),
        { 
          status: 400,
          headers: corsHeaders 
        }
      );
    }

    const { message } = requestData;

    if (!message) {
      return new Response(
        JSON.stringify({ error: 'Please provide a question about skiing.' }),
        { 
          status: 400,
          headers: corsHeaders 
        }
      );
    }

    const isApiKeyValid = await validateApiKey();
    if (!isApiKeyValid) {
      console.error('Invalid or missing OpenAI API key');
      return new Response(
        JSON.stringify({
          error: 'The service is temporarily unavailable. Please try again later.'
        }),
        {
          status: 503,
          headers: corsHeaders
        }
      );
    }

    const systemPrompt = `You are a ski safety expert providing clear, structured information about current conditions and safety recommendations for any ski resort worldwide. First, identify the resort from the user's question. If no resort is specified, ask which resort they're interested in. Always follow this format:

Quick Summary:
• Direct answer to the user's question in 1-2 sentences
• Most important safety consideration for the specified resort

Key Conditions:
• Snow Depth: [base depth] → Brief impact on skiing
• Recent Snow: [amount in last 24-48h]
• Surface Type: [powder/packed/icy] → What this means for skiers

Safety Status:
• Avalanche Risk: [level (1-5)] → Key concern areas
• Ski Patrol Status: [active/caution/closed]
• Emergency Services: [status]

Trail Conditions:
• Open Runs: [percentage]
• Groomed Areas: [key trails]
• Closed Sections: [list if any]

Recommendations:
• Most important safety gear needed
• Key precautions to take
• Best areas to ski today

If no resort is specified in the question, start your response with:
"Which ski resort would you like information about? I can provide detailed safety and conditions information for any resort worldwide."`;

    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: message }
        ],
        temperature: 0.3,
        max_tokens: 500,
      });

      const aiResponse = formatResponse(completion.choices[0].message.content || '');

      // Get follow-up questions
      const followUpCompletion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'Generate 3 short, relevant follow-up questions about ski safety for the same resort mentioned in the conversation. If no resort was specified, make the questions general. Return only the questions, one per line.'
          },
          {
            role: 'user',
            content: `Previous question: "${message}"\n\nPrevious response: "${aiResponse}"`
          }
        ],
        temperature: 0.3,
        max_tokens: 100,
      });

      const suggestedQuestions = (followUpCompletion.choices[0].message.content || '')
        .split('\n')
        .filter(q => q.trim())
        .slice(0, 3);

      return new Response(
        JSON.stringify({
          response: aiResponse,
          suggestedQuestions: suggestedQuestions
        }),
        { 
          headers: {
            ...corsHeaders,
            'Cache-Control': 'no-cache'
          }
        }
      );

    } catch (error) {
      console.error('OpenAI API error:', error);
      throw error;
    }

  } catch (error) {
    console.error('Edge function error:', error);

    let errorMessage = 'The service is temporarily unavailable. Please try again later.';
    let statusCode = 503;

    if (error instanceof Error) {
      if (error.message.includes('401')) {
        console.error('API key authentication failed');
        errorMessage = 'Authentication error. Please check the API configuration.';
        statusCode = 401;
      } else if (error.message.includes('429')) {
        console.error('Rate limit exceeded');
        errorMessage = 'Service is busy. Please try again in a moment.';
        statusCode = 429;
      }
    }

    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        status: statusCode,
        headers: corsHeaders
      }
    );
  }
});